# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Bulk::Import do
  let!(:category) { Fabricate(:category) }
  let!(:target_user) { Fabricate(:user) }
  let!(:target_actor) do
    Fabricate(:discourse_activity_pub_actor_person, local: false, model: target_user)
  end
  let!(:person2_json) { build_actor_json }
  let!(:object1_json) { build_object_json(name: "My cool title", attributed_to: target_actor) }
  let!(:object2_json) do
    build_object_json(in_reply_to: object1_json[:id], attributed_to: person2_json[:id])
  end
  let!(:create_1_json) do
    build_activity_json(actor: target_actor, object: object1_json, type: "Create")
  end
  let!(:create_2_json) do
    build_activity_json(actor: person2_json[:id], object: object2_json, type: "Create")
  end
  let!(:announce_1_json) do
    build_activity_json(actor: target_actor, object: create_1_json, type: "Announce")
  end
  let!(:announce_2_json) do
    build_activity_json(actor: person2_json[:id], object: create_2_json, type: "Announce")
  end
  let!(:ordered_collection_json) do
    build_collection_json(type: "OrderedCollection", items: [announce_1_json, announce_2_json])
  end

  describe "#perform" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

    def perform
      described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
    end

    def build_warning_log(key)
      message =
        I18n.t(
          "discourse_activity_pub.import.warning.import_did_not_start",
          actor: actor.handle,
          target_actor: target_actor.handle,
        )
      message +=
        ": " +
          I18n.t(
            "discourse_activity_pub.import.warning.#{key}",
            actor: actor.handle,
            target_actor: target_actor.handle,
          )
      prefix_log(message)
    end

    context "when the actor has full topic enabled" do
      before { toggle_activity_pub(category, callbacks: true, publication_type: "full_topic") }

      context "when not following the target actor" do
        before { setup_logging }
        after { teardown_logging }

        it "does not perform any requests" do
          described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          DiscourseActivityPub::Request.expects(:get_json_ld).never
        end

        it "logs the right warning" do
          described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          expect(@fake_logger.warnings.first).to eq(build_warning_log("not_following_target"))
        end
      end

      context "when following the target actor" do
        let!(:follow1) do
          Fabricate(:discourse_activity_pub_follow, follower: actor, followed: target_actor)
        end

        context "when target actor does not return an outbox collection" do
          before { setup_logging }
          after { teardown_logging }

          before do
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(nil)
          end

          it "does not process any activities" do
            DiscourseActivityPub::AP::Activity.expects(:process).never
            perform
          end

          it "logs the right warning" do
            perform
            expect(@fake_logger.warnings.first).to eq(build_warning_log("outbox_response_invalid"))
          end
        end

        context "when target actor returns an invalid outbox collection" do
          let!(:collection_json) do
            build_collection_json(type: "Collection", items: [create_1_json, create_2_json])
          end

          before do
            setup_logging
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(collection_json)
          end

          after { teardown_logging }

          it "does not process any activities" do
            perform
          end

          it "logs the right warning" do
            perform
            expect(@fake_logger.warnings.first).to eq(build_warning_log("outbox_response_invalid"))
          end
        end

        context "when target actor returns an outbox collection with new activities" do
          before do
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(ordered_collection_json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .once
          end

          it "finishes" do
            result = perform
            expect(result.finished).to eq(true)
          end

          it "does not create announcements" do
            perform
            expect(DiscourseActivityPubActivity.exists?(ap_type: 'Announce')).to eq(false)
          end

          it "creates the right actors" do
            result = perform
            expect(result.actors_by_ap_id.keys).to eq([target_actor.ap_id, person2_json[:id]])
            expect(DiscourseActivityPubActor.exists?(ap_id: person2_json[:id])).to eq(true)
          end

          it "creates the right activities" do
            result = perform
            activity_ap_ids = [create_1_json[:id], create_2_json[:id]]
            expect(result.activities_by_ap_id.keys).to eq(activity_ap_ids)
            expect(DiscourseActivityPubActivity.exists?(ap_id: activity_ap_ids)).to eq(true)
          end

          it "creates the right collection" do
            result = perform
            expect(result.collections_by_ap_id.keys).not_to eq([ordered_collection_json[:id]])
            collection = DiscourseActivityPubCollection.find_by(name: object1_json[:name])
            expect(collection.objects.size).to eq(2)
          end

          it "creates the right objects" do
            result = perform
            object_ap_ids = [object1_json[:id], object2_json[:id]]
            expect(result.objects_by_ap_id.keys).to eq(object_ap_ids)
          end

          it "creates the right topic" do
            result = perform
            expect(category.topics.first.title).to eq(object1_json[:name])
            expect(category.topics.first.activity_pub_object.name).to eq(object1_json[:name])
            expect(category.topics.first.activity_pub_object.objects.size).to eq(2)
          end

          it "creates the right posts" do
            perform
            posts = category.topics.first.posts
            expect(posts.first.raw).to eq(object1_json[:content])
            expect(posts.first.activity_pub_object.ap_id).to eq(object1_json[:id])
            expect(posts.first.user.activity_pub_actor.ap_id).to eq(target_actor.ap_id)
            expect(posts.second.raw).to eq(object2_json[:content])
            expect(posts.second.reply_to_post_number).to eq(posts.first.post_number)
            expect(posts.second.activity_pub_object.ap_id).to eq(object2_json[:id])
            expect(posts.second.activity_pub_object.reply_to_id).to eq(object1_json[:id])
            expect(posts.second.user.activity_pub_actor.ap_id).to eq(person2_json[:id])
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }

            it "logs the right info" do
              perform
              [
                I18n.t("discourse_activity_pub.import.info.import_started",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                ),
                I18n.t("discourse_activity_pub.import.info.created_actors", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_objects", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_collections", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_users", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_users", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_topics", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_replies", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_activities", count: 2),
                I18n.t("discourse_activity_pub.import.info.import_finished",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                )
              ].each do |info|
                expect(@fake_logger.info).to include(prefix_log(info))
              end
            end
          end
        end

        context "when target actor returns an outbox collection with new and existing activities" do
          let!(:topic) { Fabricate(:topic, category: category) }
          let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }
          let!(:post) { Fabricate(:post, topic: topic, user: target_user) }
          let!(:note) do
            Fabricate(
              :discourse_activity_pub_object_note,
              ap_id: object1_json[:id],
              local: false,
              model: post,
              collection_id: collection.id,
              attributed_to: target_actor,
            )
          end
          let!(:activity) do
            Fabricate(:discourse_activity_pub_activity_create, actor: target_actor, object: note)
          end

          before do
            activity.ap_id = create_1_json[:id]
            activity.save!

            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(ordered_collection_json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .once
          end

          it "finishes" do
            result = perform
            expect(result.finished).to eq(true)
          end

          it "does not create announcements" do
            perform
            expect(DiscourseActivityPubActivity.exists?(ap_type: 'Announce')).to eq(false)
          end

          it "creates the right number of actors" do
            expect { perform }.to change { DiscourseActivityPubActor.count }.by(1)
          end

          it "creates the right number of activities" do
            expect { perform }.to change { DiscourseActivityPubActivity.count }.by(1)
          end

          it "creates the right number of collections" do
            expect { perform }.to change { DiscourseActivityPubCollection.count }.by(0)
          end

          it "creates the right number of objects" do
            expect { perform }.to change { DiscourseActivityPubObject.count }.by(1)
          end

          it "creates the right number of topics" do
            expect { perform }.to change { Topic.count }.by(0)
          end

          it "creates the right nubmer of posts" do
            expect { perform }.to change { Post.count }.by(1)
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }

            it "logs the right info" do
              perform
              [
                I18n.t("discourse_activity_pub.import.info.import_started",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                ),
                I18n.t("discourse_activity_pub.import.info.created_actors", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_actors", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_objects", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_objects", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_collections", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_users", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_users", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_replies", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_activities", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_activities", count: 1),
                I18n.t("discourse_activity_pub.import.info.import_finished",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                )
              ].each do |info|
                expect(@fake_logger.info).to include(prefix_log(info))
              end
            end
          end
        end
      end
    end

    context "when the actor has first post enabled" do
      before { toggle_activity_pub(category, callbacks: true, publication_type: "first_post") }

      context "when following the target actor" do
        let!(:follow1) do
          Fabricate(:discourse_activity_pub_follow, follower: actor, followed: target_actor)
        end

        context "when target actor returns an outbox collection with new activities" do
          before do
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(ordered_collection_json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .once
          end

          it "finishes" do
            result = perform
            expect(result.finished).to eq(true)
          end

          it "does not create announcements" do
            perform
            expect(DiscourseActivityPubActivity.exists?(ap_type: 'Announce')).to eq(false)
          end

          it "creates the right actors" do
            result = perform
            expect(result.actors_by_ap_id.keys).to eq([target_actor.ap_id])
            expect(DiscourseActivityPubActor.exists?(ap_id: person2_json[:id])).to eq(false)
          end

          it "creates the right activities" do
            result = perform
            expect(result.activities_by_ap_id.keys).to eq([create_1_json[:id]])
            expect(DiscourseActivityPubActivity.exists?(ap_id: [create_1_json[:id]])).to eq(true)
            expect(DiscourseActivityPubActivity.exists?(ap_id: [create_2_json[:id]])).to eq(false)
          end

          it "does not create collections" do
            result = perform
            expect(result.collections_by_ap_id.keys).to eq([])
            expect(DiscourseActivityPubCollection.exists?(name: object1_json[:name])).to eq(false)
          end

          it "creates the right objects" do
            result = perform
            expect(result.objects_by_ap_id.keys).to eq([object1_json[:id]])
            expect(DiscourseActivityPubObject.exists?(ap_id: [object1_json[:id]])).to eq(true)
            expect(DiscourseActivityPubObject.exists?(ap_id: [object2_json[:id]])).to eq(false)
          end

          it "creates the right topic" do
            result = perform
            expect(category.topics.first.title).to eq(object1_json[:name])
            expect(category.topics.first.activity_pub_object).to eq(nil)
          end

          it "creates the right posts" do
            perform
            posts = category.topics.first.posts
            expect(posts.size).to eq(1)
            expect(posts.first.raw).to eq(object1_json[:content])
            expect(posts.first.activity_pub_object.ap_id).to eq(object1_json[:id])
            expect(posts.first.user.activity_pub_actor.ap_id).to eq(target_actor.ap_id)
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }

            it "logs the right info" do
              perform
              [
                I18n.t("discourse_activity_pub.import.info.import_started",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                ),
                I18n.t("discourse_activity_pub.import.info.updated_actors", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_objects", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_users", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_topics", count: 1),
                I18n.t("discourse_activity_pub.import.info.created_activities", count: 1),
                I18n.t("discourse_activity_pub.import.info.import_finished",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                )
              ].each do |info|
                expect(@fake_logger.info).to include(prefix_log(info))
              end
            end
          end
        end

        context "when target actor returns an outbox collection with new and existing activities" do
          let!(:topic) { Fabricate(:topic, category: category) }
          let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }
          let!(:post) { Fabricate(:post, topic: topic, user: target_user) }
          let!(:note) do
            Fabricate(
              :discourse_activity_pub_object_note,
              ap_id: object1_json[:id],
              local: false,
              model: post,
              collection_id: collection.id,
              attributed_to: target_actor,
            )
          end
          let!(:activity) do
            Fabricate(:discourse_activity_pub_activity_create, actor: target_actor, object: note)
          end

          before do
            activity.ap_id = create_1_json[:id]
            activity.save!

            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: target_actor.outbox)
              .returns(ordered_collection_json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .once
          end

          it "finishes" do
            result = perform
            expect(result.finished).to eq(true)
          end

          it "does not create announcements" do
            perform
            expect(DiscourseActivityPubActivity.exists?(ap_type: 'Announce')).to eq(false)
          end

          it "creates the right number of actors" do
            expect { perform }.to change { DiscourseActivityPubActor.count }.by(0)
          end

          it "creates the right number of activities" do
            expect { perform }.to change { DiscourseActivityPubActivity.count }.by(0)
          end

          it "creates the right number of collections" do
            expect { perform }.to change { DiscourseActivityPubCollection.count }.by(0)
          end

          it "creates the right number of objects" do
            expect { perform }.to change { DiscourseActivityPubObject.count }.by(0)
          end

          it "creates the right number of topics" do
            expect { perform }.to change { Topic.count }.by(0)
          end

          it "creates the right nubmer of posts" do
            expect { perform }.to change { Post.count }.by(0)
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }

            it "logs the right info" do
              perform
              [
                I18n.t("discourse_activity_pub.import.info.import_started",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                ),
                I18n.t("discourse_activity_pub.import.info.updated_actors", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_objects", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_users", count: 1),
                I18n.t("discourse_activity_pub.import.info.updated_activities", count: 1),
                I18n.t("discourse_activity_pub.import.info.import_finished",
                  actor: actor.handle,
                  target_actor: target_actor.handle,
                )
              ].each do |info|
                expect(@fake_logger.info).to include(prefix_log(info))
              end
            end
          end
        end
      end
    end
  end
end
