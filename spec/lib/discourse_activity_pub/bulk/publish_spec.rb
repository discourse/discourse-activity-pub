# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Bulk::Publish do
  let!(:category) { Fabricate(:category) }
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  describe "#perform" do
    let!(:non_performing_user) { Fabricate(:user) }
    let!(:non_performing_category) { Fabricate(:category)}
    let!(:non_performing_topic) { Fabricate(:topic, category: non_performing_category) }
    let!(:non_performing_post) { Fabricate(:post, topic: non_performing_topic, user: non_performing_user) }

    before { freeze_time }
    after { unfreeze_time }

    def build_warning_log(key)
      message =
        I18n.t(
          "discourse_activity_pub.publish.warning.publish_did_not_start",
          actor: actor.handle
        )
      message +=
        ": " +
          I18n.t(
            "discourse_activity_pub.publish.warning.#{key}",
            actor: actor.handle
          )
      prefix_log(message)
    end

    context "when the actor has full topic enabled" do
      before { toggle_activity_pub(category, callbacks: true, publication_type: "full_topic") }

      context "when the actor has models without ap objects" do
        let!(:topic1) { Fabricate(:topic, category: category) }
        let!(:topic2) { Fabricate(:topic, category: category) }
        let!(:post1) { Fabricate(:post, topic: topic1) }
        let!(:post2) { Fabricate(:post, topic: topic1, reply_to_post_number: 1) }
        let!(:post3) { Fabricate(:post, topic: topic2) }
        let!(:post4) { Fabricate(:post, topic: topic2) }

        it "returns the right result" do
          result = described_class.perform(actor_id: actor.id)
          expect(result.collections.count).to eq(2)
          expect(result.actors.count).to eq(4)
          expect(result.objects.count).to eq(4)
          expect(result.activities.count).to eq(4)
          expect(result.announcements.count).to eq(4)
          expect(result.ap_ids.count).to eq(18)
        end

        it "creates the right collections" do
          described_class.perform(actor_id: actor.id)
          expect(topic1.activity_pub_object.name).to eq(topic1.title)
          expect(topic2.activity_pub_object.name).to eq(topic2.title)
          expect(topic1.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(topic2.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
        end

        it "creates the right actors" do
          described_class.perform(actor_id: actor.id)
          expect(post1.user.activity_pub_actor.name).to eq(post1.user.name)
          expect(post2.user.activity_pub_actor.name).to eq(post2.user.name)
          expect(post3.user.activity_pub_actor.name).to eq(post3.user.name)
          expect(post4.user.activity_pub_actor.name).to eq(post4.user.name)
          expect(post1.user.activity_pub_actor.username).to eq(post1.user.username)
          expect(post2.user.activity_pub_actor.username).to eq(post2.user.username)
          expect(post3.user.activity_pub_actor.username).to eq(post3.user.username)
          expect(post4.user.activity_pub_actor.username).to eq(post4.user.username)
        end

        it "creates the right post objects" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.content).to eq(post1.raw)
          expect(post2.activity_pub_object.content).to eq(post2.raw)
          expect(post3.activity_pub_object.content).to eq(post3.raw)
          expect(post4.activity_pub_object.content).to eq(post4.raw)
          expect(post2.activity_pub_object.reply_to_id).to eq(post1.activity_pub_object.ap_id)
          expect(post4.activity_pub_object.reply_to_id).to eq(post3.activity_pub_object.ap_id)
          expect(post1.activity_pub_object.collection_id).to eq(post1.topic.activity_pub_object.id)
          expect(post2.activity_pub_object.collection_id).to eq(post2.topic.activity_pub_object.id)
          expect(post3.activity_pub_object.collection_id).to eq(post3.topic.activity_pub_object.id)
          expect(post4.activity_pub_object.collection_id).to eq(post4.topic.activity_pub_object.id)
          expect(post1.activity_pub_object.attributed_to_id).to eq(post1.user.activity_pub_actor.ap_id)
          expect(post2.activity_pub_object.attributed_to_id).to eq(post2.user.activity_pub_actor.ap_id)
          expect(post3.activity_pub_object.attributed_to_id).to eq(post3.user.activity_pub_actor.ap_id)
          expect(post4.activity_pub_object.attributed_to_id).to eq(post4.user.activity_pub_actor.ap_id)
          expect(post1.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(post2.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(post4.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(post1.activity_pub_content).to eq(post1.raw)
          expect(post2.activity_pub_content).to eq(post2.raw)
          expect(post3.activity_pub_content).to eq(post3.raw)
          expect(post4.activity_pub_content).to eq(post3.raw)
          expect(post1.activity_pub_visibility).to eq('public')
          expect(post2.activity_pub_visibility).to eq('public')
          expect(post3.activity_pub_visibility).to eq('public')
          expect(post4.activity_pub_visibility).to eq('public')
          expect(post1.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
          expect(post2.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
          expect(post3.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
          expect(post4.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
        end

        it "creates the right activities" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post2.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post3.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post4.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post1.activity_pub_object.activities.first.actor.id).to eq(post1.user.activity_pub_actor.id)
          expect(post2.activity_pub_object.activities.first.actor.id).to eq(post2.user.activity_pub_actor.id)
          expect(post3.activity_pub_object.activities.first.actor.id).to eq(post3.user.activity_pub_actor.id)
          expect(post4.activity_pub_object.activities.first.actor.id).to eq(post4.user.activity_pub_actor.id)
          expect(post1.activity_pub_object.activities.first.object.id).to eq(post1.activity_pub_object.id)
          expect(post2.activity_pub_object.activities.first.object.id).to eq(post2.activity_pub_object.id)
          expect(post3.activity_pub_object.activities.first.object.id).to eq(post3.activity_pub_object.id)
          expect(post4.activity_pub_object.activities.first.object.id).to eq(post4.activity_pub_object.id)
          expect(post1.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post2.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post3.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post4.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post1.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
          expect(post2.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
          expect(post4.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
        end

        it "creates the right announcements" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post2.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post3.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post4.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post1.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          expect(post2.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          expect(post4.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
        end

        it "creates objects in the right order" do
          described_class.perform(actor_id: actor.id)
          expect(
            DiscourseActivityPubObject
              .joins("JOIN posts ON discourse_activity_pub_objects.model_type = 'Post' AND discourse_activity_pub_objects.model_id = posts.id")
              .order('discourse_activity_pub_objects.created_at')
              .pluck("posts.id")
          ).to eq([post1.id, post2.id, post3.id, post4.id])
        end

        it "creates activities in the right order" do
          described_class.perform(actor_id: actor.id)
          expect(
            DiscourseActivityPubActivity
              .joins("JOIN discourse_activity_pub_objects o ON discourse_activity_pub_activities.object_type = 'DiscourseActivityPubObject' AND discourse_activity_pub_activities.object_id = o.id")
              .joins("JOIN posts ON o.model_type = 'Post' AND o.model_id = posts.id")
              .order('o.created_at')
              .pluck("posts.id")
          ).to eq([post1.id, post2.id, post3.id, post4.id])
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "logs the right info" do
            described_class.perform(actor_id: actor.id)
            expect(@fake_logger.info.first).to eq(
              prefix_log(
                I18n.t(
                  "discourse_activity_pub.publish.info.publish_started",
                  actor: actor.handle
                ),
              ),
            )
            expect(@fake_logger.info.second).to eq(
              prefix_log(
                I18n.t(
                  "discourse_activity_pub.publish.info.publish_finished",
                  actor: actor.handle,
                  activities_count: 4,
                ),
              ),
            )
          end
        end
      end

      context "when the actor has models with published ap objects and models without ap objects" do
        let!(:topic1) { Fabricate(:topic, category: category) }
        let!(:topic2) { Fabricate(:topic, category: category) }
        let!(:post1) { Fabricate(:post, topic: topic1) }
        let!(:post2) { Fabricate(:post, topic: topic1, reply_to_post_number: 1) }
        let!(:post3) { Fabricate(:post, topic: topic2) }
        let!(:collection1) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic1, published_at: Time.now)}
        let!(:actor1) { Fabricate(:discourse_activity_pub_actor, ap_type: 'Person', model: post1.user)}
        let!(:object1) { Fabricate(:discourse_activity_pub_object_note, model: post1, published_at: Time.now, collection_id: collection1.id, attributed_to: actor1)}
        let!(:activity1) { Fabricate(:discourse_activity_pub_activity_create, actor: actor1, object: object1, published_at: Time.now)}

        it "returns the right result" do
          result = described_class.perform(actor_id: actor.id)
          expect(result.collections.count).to eq(1)
          expect(result.actors.count).to eq(2)
          expect(result.objects.count).to eq(2)
          expect(result.activities.count).to eq(2)
          expect(result.announcements.count).to eq(3)
          expect(result.ap_ids.count).to eq(10)
        end

        it "creates the right collections" do
          described_class.perform(actor_id: actor.id)
          expect(topic2.activity_pub_object.name).to eq(topic2.title)
          expect(topic2.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
        end

        it "creates the right actors" do
          described_class.perform(actor_id: actor.id)
          expect(post2.user.activity_pub_actor.name).to eq(post2.user.name)
          expect(post3.user.activity_pub_actor.name).to eq(post3.user.name)
          expect(post2.user.activity_pub_actor.username).to eq(post2.user.username)
          expect(post3.user.activity_pub_actor.username).to eq(post3.user.username)
        end

        it "creates the right post objects" do
          described_class.perform(actor_id: actor.id)
          expect(post2.activity_pub_object.content).to eq(post2.raw)
          expect(post3.activity_pub_object.content).to eq(post3.raw)
          expect(post2.activity_pub_object.reply_to_id).to eq(post1.activity_pub_object.ap_id)
          expect(post2.activity_pub_object.collection_id).to eq(post2.topic.activity_pub_object.id)
          expect(post3.activity_pub_object.collection_id).to eq(post3.topic.activity_pub_object.id)
          expect(post2.activity_pub_object.attributed_to_id).to eq(post2.user.activity_pub_actor.ap_id)
          expect(post3.activity_pub_object.attributed_to_id).to eq(post3.user.activity_pub_actor.ap_id)
          expect(post2.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          expect(post2.activity_pub_content).to eq(post2.raw)
          expect(post3.activity_pub_content).to eq(post3.raw)
          expect(post2.activity_pub_visibility).to eq('public')
          expect(post3.activity_pub_visibility).to eq('public')
          expect(post2.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
          expect(post3.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
        end

        it "creates the right activities" do
          described_class.perform(actor_id: actor.id)
          expect(post2.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post3.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post2.activity_pub_object.activities.first.actor.id).to eq(post2.user.activity_pub_actor.id)
          expect(post3.activity_pub_object.activities.first.actor.id).to eq(post3.user.activity_pub_actor.id)
          expect(post2.activity_pub_object.activities.first.object.id).to eq(post2.activity_pub_object.id)
          expect(post3.activity_pub_object.activities.first.object.id).to eq(post3.activity_pub_object.id)
          expect(post2.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post3.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post2.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
        end

        it "creates the right announcements" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post2.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post3.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post1.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          expect(post2.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "logs the right info" do
            described_class.perform(actor_id: actor.id)
            expect(@fake_logger.info.first).to eq(
              prefix_log(
                I18n.t(
                  "discourse_activity_pub.publish.info.publish_started",
                  actor: actor.handle
                ),
              ),
            )
            expect(@fake_logger.info.second).to eq(
              prefix_log(
                I18n.t(
                  "discourse_activity_pub.publish.info.publish_finished",
                  actor: actor.handle,
                  activities_count: 2,
                ),
              ),
            )
          end
        end

        context "with models with unpublished ap objects" do
          let!(:actor2) { Fabricate(:discourse_activity_pub_actor, ap_type: 'Person', model: post2.user)}
          let!(:object2) { Fabricate(:discourse_activity_pub_object_note, model: post2, published_at: nil, collection_id: collection1.id, attributed_to: actor2, reply_to_id: object1.ap_id)}
          let!(:activity2) { Fabricate(:discourse_activity_pub_activity_create, actor: actor2, object: object2, published_at: nil)}

          it "returns the right result" do
            result = described_class.perform(actor_id: actor.id)
            expect(result.collections.count).to eq(1)
            expect(result.actors.count).to eq(1)
            expect(result.objects.count).to eq(2)
            expect(result.activities.count).to eq(2)
            expect(result.announcements.count).to eq(3)
            expect(result.ap_ids.count).to eq(9)
          end
  
          it "creates the right collections" do
            described_class.perform(actor_id: actor.id)
            expect(topic2.activity_pub_object.name).to eq(topic2.title)
            expect(topic2.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
          end
  
          it "creates the right actors" do
            described_class.perform(actor_id: actor.id)
            expect(post3.user.activity_pub_actor.name).to eq(post3.user.name)
            expect(post3.user.activity_pub_actor.username).to eq(post3.user.username)
          end
  
          it "creates and publishes the right post objects" do
            described_class.perform(actor_id: actor.id)
            expect(post3.activity_pub_object.content).to eq(post3.raw)
            expect(post3.activity_pub_object.collection_id).to eq(post3.topic.activity_pub_object.id)
            expect(post3.activity_pub_object.attributed_to_id).to eq(post3.user.activity_pub_actor.ap_id)
            expect(post2.reload.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
            expect(post3.activity_pub_object.published_at).to be_within_one_second_of(Time.now)
            expect(post3.activity_pub_content).to eq(post3.raw)
            expect(post3.activity_pub_visibility).to eq('public')
            expect(post2.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
            expect(post3.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
          end
  
          it "creates and publishes the right activities" do
            described_class.perform(actor_id: actor.id)
            expect(post3.activity_pub_object.activities.first.ap_type).to eq("Create")
            expect(post3.activity_pub_object.activities.first.actor.id).to eq(post3.user.activity_pub_actor.id)
            expect(post3.activity_pub_object.activities.first.object.id).to eq(post3.activity_pub_object.id)
            expect(post3.activity_pub_object.activities.first.visibility).to eq(2)
            expect(activity2.reload.published_at).to be_within_one_second_of(Time.now)
            expect(post3.activity_pub_object.activities.first.reload.published_at).to be_within_one_second_of(Time.now)
          end

          it "creates the right announcements" do
            described_class.perform(actor_id: actor.id)
            expect(post1.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
            expect(post2.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
            expect(post3.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
            expect(post1.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
            expect(post2.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
            expect(post3.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          end
        end
      end
    end

    context "when the actor has first_post enabled" do
      before { toggle_activity_pub(category, callbacks: true, publication_type: "first_post") }

      context "when the actor has models without ap objects" do
        let!(:topic1) { Fabricate(:topic, category: category) }
        let!(:topic2) { Fabricate(:topic, category: category) }
        let!(:post1) { Fabricate(:post, topic: topic1) }
        let!(:post2) { Fabricate(:post, topic: topic1, reply_to_post_number: 1) }
        let!(:post3) { Fabricate(:post, topic: topic2) }

        it "returns the right result" do
          result = described_class.perform(actor_id: actor.id)
          expect(result.collections.count).to eq(0)
          expect(result.actors.count).to eq(2)
          expect(result.objects.count).to eq(2)
          expect(result.activities.count).to eq(2)
          expect(result.announcements.count).to eq(2)
          expect(result.ap_ids.count).to eq(8)
        end

        it "creates the right actors" do
          described_class.perform(actor_id: actor.id)
          expect(post1.user.activity_pub_actor.name).to eq(post1.user.name)
          expect(post3.user.activity_pub_actor.name).to eq(post3.user.name)
          expect(post1.user.activity_pub_actor.username).to eq(post1.user.username)
          expect(post3.user.activity_pub_actor.username).to eq(post3.user.username)
        end

        it "creates the right post objects" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.content).to eq(post1.raw)
          expect(post3.activity_pub_object.content).to eq(post3.raw)
          expect(post1.activity_pub_content).to eq(post1.raw)
          expect(post3.activity_pub_content).to eq(post3.raw)
          expect(post1.activity_pub_visibility).to eq('public')
          expect(post3.activity_pub_visibility).to eq('public')
          expect(post1.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
          expect(post3.custom_fields["activity_pub_published_at"].to_time).to be_within_one_second_of(Time.now)
        end

        it "creates the right activities" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post3.activity_pub_object.activities.first.ap_type).to eq("Create")
          expect(post1.activity_pub_object.activities.first.actor.id).to eq(post1.user.activity_pub_actor.id)
          expect(post3.activity_pub_object.activities.first.actor.id).to eq(post3.user.activity_pub_actor.id)
          expect(post1.activity_pub_object.activities.first.object.id).to eq(post1.activity_pub_object.id)
          expect(post3.activity_pub_object.activities.first.object.id).to eq(post3.activity_pub_object.id)
          expect(post1.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post3.activity_pub_object.activities.first.visibility).to eq(2)
          expect(post1.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.activities.first.published_at).to be_within_one_second_of(Time.now)
        end

        it "creates the right announcements" do
          described_class.perform(actor_id: actor.id)
          expect(post1.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post3.activity_pub_object.activities.first.announcement.actor_id).to eq(category.activity_pub_actor.id)
          expect(post1.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
          expect(post3.activity_pub_object.activities.first.announcement.published_at).to be_within_one_second_of(Time.now)
        end

        context "with verbose logging enabled" do
          before { setup_logging }
          after { teardown_logging }

          it "logs the right info" do
            described_class.perform(actor_id: actor.id)
            expect(@fake_logger.info.first).to eq(
              prefix_log(
                I18n.t(
                  "discourse_activity_pub.publish.info.publish_started",
                  actor: actor.handle
                ),
              ),
            )
            expect(@fake_logger.info.second).to eq(
              prefix_log(
                I18n.t(
                  "discourse_activity_pub.publish.info.publish_finished",
                  actor: actor.handle,
                  activities_count: 2,
                ),
              ),
            )
          end
        end
      end
    end
  end
end
