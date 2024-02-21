# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::OutboxImporter do
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
  let!(:ordered_collection_json) do
    build_collection_json(type: "OrderedCollection", items: [create_1_json, create_2_json])
  end

  describe "#perform" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

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

    context "when the actor is ready" do
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
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          end

          it "logs the right warning" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
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
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
          end

          it "logs the right warning" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
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
              .with(uri: target_actor.ap_id)
              .returns(target_actor.ap.json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .twice
          end

          it "returns the right result" do
            result = described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(result[:success]).to eq([create_1_json[:id], create_2_json[:id]])
          end

          it "creates the right topic" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(category.topics.first.title).to eq(object1_json[:name])
          end

          it "creates the right posts" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            posts = category.topics.first.posts
            expect(posts.first.raw).to eq(object1_json[:content])
            expect(posts.second.raw).to eq(object2_json[:content])
          end

          it "creates the right actors" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(DiscourseActivityPubActor.exists?(ap_id: person2_json[:id])).to eq(true)
          end

          it "creates the right activities" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(
              DiscourseActivityPubActivity.exists?(ap_id: [create_1_json[:id], create_2_json[:id]]),
            ).to eq(true)
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }

            it "logs the right info" do
              described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
              expect(@fake_logger.info.first).to eq(
                prefix_log(
                  I18n.t(
                    "discourse_activity_pub.import.info.import_started",
                    actor: actor.handle,
                    target_actor: target_actor.handle,
                    activity_count: 2,
                  ),
                ),
              )
              expect(@fake_logger.info.second).to eq(
                prefix_log(
                  I18n.t(
                    "discourse_activity_pub.import.info.import_finished",
                    actor: actor.handle,
                    target_actor: target_actor.handle,
                    success_count: 2,
                  ),
                ),
              )
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
              .with(uri: target_actor.ap_id)
              .returns(target_actor.ap.json)
            DiscourseActivityPub::Request
              .expects(:get_json_ld)
              .with(uri: person2_json[:id])
              .returns(person2_json)
              .twice
          end

          it "returns the right result" do
            result = described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(result[:success]).to eq([create_2_json[:id]])
            expect(result[:failure]).to eq([create_1_json[:id]])
          end

          it "creates the right topic" do
            topic_count = category.topics.size
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(category.topics.size).to eq(topic_count)
          end

          it "creates the right posts" do
            posts_count = category.topics.first.posts.size
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            posts = category.topics.first.posts
            expect(posts.size).to eq(posts_count + 1)
            expect(posts.second.raw).to eq(object2_json[:content])
          end

          it "creates the right actors" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(DiscourseActivityPubActor.exists?(ap_id: person2_json[:id])).to eq(true)
          end

          it "creates the right activities" do
            described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
            expect(DiscourseActivityPubActivity.exists?(ap_id: [create_2_json[:id]])).to eq(true)
          end

          context "with verbose logging enabled" do
            before { setup_logging }
            after { teardown_logging }

            it "logs the right info" do
              described_class.perform(actor_id: actor.id, target_actor_id: target_actor.id)
              expect(@fake_logger.info.first).to eq(
                prefix_log(
                  I18n.t(
                    "discourse_activity_pub.import.info.import_started",
                    actor: actor.handle,
                    target_actor: target_actor.handle,
                    activity_count: 2,
                  ),
                ),
              )
              expect(@fake_logger.info.second).to eq(
                prefix_log(
                  I18n.t(
                    "discourse_activity_pub.import.info.import_finished",
                    actor: actor.handle,
                    target_actor: target_actor.handle,
                    success_count: 1,
                    failure_count: 1,
                  ),
                ),
              )
            end
          end
        end
      end
    end
  end
end
