# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ActivityForwarder do
  let!(:category) { Fabricate(:category) }
  let!(:category_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }
  let!(:post1) { Fabricate(:post, topic: topic, post_number: 1) }
  let!(:contributor1) do
    Fabricate(:discourse_activity_pub_actor_person, local: true, model: post1.user)
  end
  let!(:note1) do
    Fabricate(
      :discourse_activity_pub_object_note,
      local: true,
      model: post1,
      published_at: Time.now,
      collection_id: collection.id,
      attributed_to: contributor1,
    )
  end
  let!(:post2) { Fabricate(:post, topic: topic, post_number: 2) }
  let!(:contributor2) do
    Fabricate(:discourse_activity_pub_actor_person, local: true, model: post2.user)
  end
  let!(:note2) do
    Fabricate(
      :discourse_activity_pub_object_note,
      local: true,
      model: post2,
      published_at: Time.now,
      collection_id: collection.id,
      attributed_to: contributor2,
    )
  end
  let!(:post3) { Fabricate(:post, topic: topic, post_number: 3) }
  let!(:contributor3) do
    Fabricate(:discourse_activity_pub_actor_person, local: false, model: post3.user)
  end
  let!(:note3) do
    Fabricate(
      :discourse_activity_pub_object_note,
      local: false,
      model: post3,
      published_at: Time.now,
      collection_id: collection.id,
      attributed_to: contributor3,
    )
  end

  let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
  let!(:follow1) do
    Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category_actor)
  end
  let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
  let!(:follow2) do
    Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: category_actor)
  end

  let!(:activity) do
    Fabricate(:discourse_activity_pub_activity_like, object: note3, published_at: Time.now)
  end
  let!(:announcement) { activity.announce!(category_actor.id) }

  describe "#perform" do
    before do
      Jobs.run_immediately!
      toggle_activity_pub(category, publication_type: "full_topic")
      freeze_time
    end

    after { unfreeze_time }

    def perform_process(activity)
      described_class.perform(activity.ap)
    end

    shared_examples "topic actor forward" do
      it "forwards to followers and remote contributors" do
        expect_request(
          actor_id: topic.activity_pub_actor.id,
          body: announcement.ap.json,
          returns: stub_everything(post_json_ld: true),
          uri: [follower1.inbox, follower2.inbox, contributor3.inbox],
        ).times(3)
        perform_process(activity)
      end

      it "forwards to actors the activity is already addressed to" do
        expect_request(
          actor_id: topic.activity_pub_actor.id,
          body: announcement.ap.json,
          returns: stub_everything(post_json_ld: true),
          uri: [follower1.inbox, follower2.inbox, contributor3.inbox],
        ).times(3)
        activity.ap.json[:cc] << follower1.ap_id
        perform_process(activity)
      end

      it "does not forward to the activity actor" do
        DiscourseActivityPub::Request
          .expects(:new)
          .with { |args| args[:uri] != activity.actor.inbox }
          .returns(stub_everything(post_json_ld: true))
          .times(3)
        perform_process(activity)
      end

      it "does not change the object model custom fields" do
        published_at = Time.now
        post4 = Fabricate(:post, topic: topic, post_number: 4)
        post4.custom_fields["activity_pub_published_at"] = published_at
        post4.save_custom_fields(true)
        note4 =
          Fabricate(
            :discourse_activity_pub_object_note,
            local: false,
            model: post4,
            published_at: published_at,
            collection_id: collection.id,
          )
        create_activity =
          Fabricate(
            :discourse_activity_pub_activity_create,
            object: note4,
            published_at: published_at,
          )
        perform_process(create_activity)
        expect(post4.reload.activity_pub_published_at.to_datetime.to_i).to eq_time(
          published_at.to_i,
        )
      end
    end

    context "with a new activity" do
      before { activity.ap.cache["new"] = true }

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
            follower2.model_id = Fabricate(:user).id
            follower2.model_type = "User"
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
          before { activity.ap.json[:cc] = [DiscourseActivityPub::JsonLd.public_collection_id] }

          context "when the first post note is remote" do
            let!(:remote_topic_actor_ap_id) { DiscourseActivityPub::JsonLd.generate_id("Actor") }
            let!(:remote_topic_actor) do
              Fabricate(
                :discourse_activity_pub_actor,
                ap_id: remote_topic_actor_ap_id,
                local: false,
              )
            end

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
                  uri: remote_topic_actor.inbox,
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
