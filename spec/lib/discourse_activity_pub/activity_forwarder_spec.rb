# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ActivityForwarder do
  let!(:category) { Fabricate(:category) }
  let!(:category_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }
  let!(:post1) { Fabricate(:post, topic: topic, post_number: 1) }
  let!(:note1) { Fabricate(:discourse_activity_pub_object_note, local: true, model: post1, published_at: Time.now, collection_id: collection.id) }
  let!(:post2) { Fabricate(:post, topic: topic, post_number: 2) }
  let!(:note2) { Fabricate(:discourse_activity_pub_object_note, local: true, model: post2, published_at: Time.now, collection_id: collection.id) }
  let!(:post3) { Fabricate(:post, topic: topic, post_number: 3) }
  let!(:note3) { Fabricate(:discourse_activity_pub_object_note, local: false, model: post3, published_at: Time.now, collection_id: collection.id) }

  let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
  let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category_actor) }
  let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
  let!(:follow2) { Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: category_actor) }

  let!(:activity) { Fabricate(:discourse_activity_pub_activity_like, object: note3, published_at: Time.now) }
  let!(:announcement) { activity.announce!(category_actor.id) }

  describe "#perform" do
    before do
      Jobs.run_immediately!
      toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
      freeze_time
    end

    after do
      unfreeze_time
    end

    def perform_process(activity)
      described_class.perform(activity.ap)
    end

    shared_examples "topic actor forward" do
      it "forwards to followers" do
        expect_request(
          actor_id: topic.activity_pub_actor.id,
          body: announcement.ap.json,
          returns: stub_everything(post_json_ld: true),
          uri: [follower1.inbox, follower2.inbox]
        ).twice
        perform_process(activity)
      end

      it "forwards to followers the activity is already addressed to" do
        expect_request(
          actor_id: topic.activity_pub_actor.id,
          body: announcement.ap.json,
          returns: stub_everything(post_json_ld: true),
          uri: [follower1.inbox, follower2.inbox]
        ).twice
        activity.ap.json[:cc] << follower1.ap_id
        perform_process(activity)
      end
    end

    context "with a new activity" do
      before do
        activity.ap.cache['new'] = true
      end

      context "with a close local object" do
        before do
          post3.reply_to_post_number = post2.post_number
          note3.reply_to_id = note2.ap_id
          note3.save!
        end

        context "when the activity is addressed to the topic actor" do
          before do
            activity.ap.json[:to] = topic.activity_pub_actor.ap_id
            activity.ap.json[:cc] = []
          end

          include_examples "topic actor forward"
        end

        context "when the activity is not addressed to the topic actor" do
          before do
            follower2.model_id = post3.user_id
            follower2.model_type = 'User'
            follower2.save!

            activity.ap.json[:to] = follower2.ap_id
            activity.ap.json[:cc] = []
          end

          it "does not forward to the topic actor's followers" do
            expect_no_delivery
            perform_process(activity)
          end
        end

        context "when the activity is publicly addressed" do
          before do
            activity.ap.json[:cc] = [DiscourseActivityPub::JsonLd.public_collection_id]
          end
  
          context "when the first post note is remote" do
            let!(:remote_topic_actor_ap_id) { "https://forum.com/actor/12345" }
            let!(:remote_topic_actor) { Fabricate(:discourse_activity_pub_actor, ap_id: remote_topic_actor_ap_id, local: false) }
  
            before do
              note1.local = false
              note1.save!
            end
  
            context "when it has an audience" do
              before do
                note1.audience = remote_topic_actor_ap_id
                note1.save!
              end
  
              it "forwards to the audience" do
                expect_request(
                  actor_id: topic.activity_pub_actor.id,
                  body: announcement.ap.json,
                  returns: stub_everything(post_json_ld: true),
                  uri: remote_topic_actor.inbox
                ).once
                perform_process(activity)
              end
            end
          end
  
          context "when the first post note is local" do
            before do
              note1.local = true
              note1.save!
            end

            include_examples "topic actor forward"
          end
        end
      end

      context "without a close local object" do
        it "does not foward" do
          expect_no_delivery
          perform_process(activity)
        end
      end
    end
  end
end