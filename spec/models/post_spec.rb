# frozen_string_literal: true

RSpec.describe Post do
  let(:category) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }
  let(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:reply) { Fabricate(:post, topic: topic, post_number: 2, reply_to_post_number: 1) }

  it { is_expected.to have_one(:activity_pub_object) }

  describe "#activity_pub_enabled" do
    context "with activity pub plugin enabled" do
      context "with activity pub set to first post on category" do
        before { toggle_activity_pub(category) }

        context "when first post in topic" do
          it { expect(post.activity_pub_enabled).to eq(true) }
        end

        context "when not first post in topic" do
          it { expect(reply.activity_pub_enabled).to eq(false) }
        end
      end

      context "with activity pub not ready on category" do
        it { expect(post.activity_pub_enabled).to eq(false) }
      end

      context "with activity pub set to full topic on category" do
        before do
          toggle_activity_pub(category, publication_type: "full_topic")
          topic.create_activity_pub_collection!
        end

        context "when first post in topic" do
          it { expect(post.activity_pub_enabled).to eq(true) }
        end

        context "when not first post in topic" do
          it { expect(reply.activity_pub_enabled).to eq(true) }
        end
      end

      context "with activity pub set to first post on tag" do
        before { toggle_activity_pub(tag) }

        context "when first post in topic" do
          it { expect(post.activity_pub_enabled).to eq(true) }
        end

        context "when not first post in topic" do
          it { expect(reply.activity_pub_enabled).to eq(false) }
        end
      end

      context "with activity pub set to full topic on tag" do
        before do
          toggle_activity_pub(tag, publication_type: "full_topic")
          topic.create_activity_pub_collection!
        end

        context "when first post in topic" do
          it { expect(post.activity_pub_enabled).to eq(true) }
        end

        context "when not first post in topic" do
          it { expect(reply.activity_pub_enabled).to eq(true) }
        end
      end

      context "with a private message" do
        let!(:post) { Fabricate(:private_message_post) }

        it { expect(post.activity_pub_enabled).to eq(false) }
      end
    end

    context "with activity pub plugin disabled" do
      it { expect(post.activity_pub_enabled).to eq(false) }
    end
  end

  describe "#activity_pub_publish_state" do
    let(:group) { Fabricate(:group) }
    let!(:category_moderation_group) { Fabricate(:category_moderation_group, group:, category:) }

    context "with activity pub ready on category" do
      before { toggle_activity_pub(category) }

      it "publishes status only to staff and category moderators" do
        message =
          MessageBus.track_publish("/activity-pub") { post.activity_pub_publish_state }.first
        expect(message.group_ids).to eq([Group::AUTO_GROUPS[:staff], group.id])
      end

      context "with status changes" do
        before do
          freeze_time

          post.custom_fields["activity_pub_published_at"] = 2.days.ago.iso8601(3)
          post.custom_fields["activity_pub_deleted_at"] = Time.now.iso8601(3)
          post.save_custom_fields(true)
        end

        it "publishes the correct status" do
          message =
            MessageBus.track_publish("/activity-pub") { post.activity_pub_publish_state }.first
          expect(message.data[:model][:id]).to eq(post.id)
          expect(message.data[:model][:type]).to eq("post")
          expect(message.data[:model][:published_at]).to eq(2.days.ago.iso8601(3))
          expect(message.data[:model][:deleted_at]).to eq(Time.now.iso8601(3))
        end
      end
    end

    context "with activity pub ready on tag" do
      before { toggle_activity_pub(tag) }

      it "publishes status only to staff" do
        message =
          MessageBus.track_publish("/activity-pub") { post.activity_pub_publish_state }.first
        expect(message.group_ids).to eq([Group::AUTO_GROUPS[:staff]])
      end
    end
  end

  describe "#activity_pub_publish!" do
    context "when post is published" do
      before do
        post.custom_fields["activity_pub_published_at"] = Time.now
        post.save_custom_fields(true)
      end

      it "does not attempt an activity" do
        post.expects(:perform_activity_pub_activity).never
        post.activity_pub_publish!
      end

      it "returns false" do
        expect(post.activity_pub_publish!).to eq(false)
      end
    end

    context "when post is not published" do
      context "with first_post enabled on category" do
        before { toggle_activity_pub(category, publication_type: "first_post") }

        it "does not attempt to create a post user actor" do
          DiscourseActivityPub::ActorHandler.expects(:update_or_create_actor).never
          post.activity_pub_publish!
        end

        it "sets the post content" do
          post.activity_pub_publish!
          expect(post.reload.activity_pub_content).to eq(post.cooked)
        end

        it "sets the post visibility" do
          post.activity_pub_publish!
          expect(post.reload.activity_pub_visibility).to eq("public")
        end

        it "attempts a create activity" do
          post.expects(:perform_activity_pub_activity).with(:create).once
          post.activity_pub_publish!
        end

        it "returns the outcome of the create activity" do
          post.stubs(:perform_activity_pub_activity).with(:create).returns(true)
          expect(post.activity_pub_publish!).to eq(true)
        end
      end

      context "with full_topic enabled on category" do
        before { toggle_activity_pub(category, publication_type: "full_topic") }

        context "with a topic collection" do
          before { post.topic.create_activity_pub_collection! }

          it "attemps to create a post user actor" do
            DiscourseActivityPub::ActorHandler.expects(:update_or_create_actor).once
            post.activity_pub_publish!
          end

          it "sets the post content" do
            post.activity_pub_publish!
            expect(post.reload.activity_pub_content).to eq(post.cooked)
          end

          it "sets the post visibility" do
            post.activity_pub_publish!
            expect(post.reload.activity_pub_visibility).to eq("public")
          end

          it "attempts a create activity" do
            post.expects(:perform_activity_pub_activity).with(:create).once
            post.activity_pub_publish!
          end

          it "returns the outcome of the create activity" do
            post.stubs(:perform_activity_pub_activity).with(:create).returns(true)
            expect(post.activity_pub_publish!).to eq(true)
          end
        end

        context "without a topic collection" do
          it "creates the topic collections" do
            post.activity_pub_publish!
            expect(post.topic.activity_pub_object).to be_present
          end
        end
      end

      context "with first_post enabled on tag" do
        before { toggle_activity_pub(tag, publication_type: "first_post") }

        it "does not attempt to create a post user actor" do
          DiscourseActivityPub::ActorHandler.expects(:update_or_create_actor).never
          post.activity_pub_publish!
        end

        it "sets the post content" do
          post.activity_pub_publish!
          expect(post.reload.activity_pub_content).to eq(post.cooked)
        end

        it "sets the post visibility" do
          post.activity_pub_publish!
          expect(post.reload.activity_pub_visibility).to eq("public")
        end

        it "attempts a create activity" do
          post.expects(:perform_activity_pub_activity).with(:create).once
          post.activity_pub_publish!
        end

        it "returns the outcome of the create activity" do
          post.stubs(:perform_activity_pub_activity).with(:create).returns(true)
          expect(post.activity_pub_publish!).to eq(true)
        end
      end

      context "with full_topic enabled on tag" do
        before do
          toggle_activity_pub(tag, publication_type: "full_topic")
          post.topic.create_activity_pub_collection!
        end

        it "attemps to create a post user actor" do
          DiscourseActivityPub::ActorHandler.expects(:update_or_create_actor).once
          post.activity_pub_publish!
        end

        it "sets the post content" do
          post.activity_pub_publish!
          expect(post.reload.activity_pub_content).to eq(post.cooked)
        end

        it "sets the post visibility" do
          post.activity_pub_publish!
          expect(post.reload.activity_pub_visibility).to eq("public")
        end

        it "attempts a create activity" do
          post.expects(:perform_activity_pub_activity).with(:create).once
          post.activity_pub_publish!
        end

        it "returns the outcome of the create activity" do
          post.stubs(:perform_activity_pub_activity).with(:create).returns(true)
          expect(post.activity_pub_publish!).to eq(true)
        end
      end
    end
  end

  describe "#activity_pub_delete!" do
    before { toggle_activity_pub(category, publication_type: "first_post") }

    context "with a post with a remote Note" do
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post, local: false) }

      it "does not attempt an activity" do
        post.expects(:perform_activity_pub_activity).never
        post.activity_pub_delete!
      end

      it "returns false" do
        expect(post.activity_pub_delete!).to eq(false)
      end
    end

    context "with a post with a local Note" do
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post, local: true) }

      before do
        post.custom_fields["activity_pub_scheduled_at"] = Time.now
        post.custom_fields["activity_pub_published_at"] = Time.now
        post.save_custom_fields(true)
      end

      it "attempts a delete activity" do
        post.expects(:perform_activity_pub_activity).with(:delete).once
        post.activity_pub_delete!
      end

      it "removes published_at and scheduled_at timestamps" do
        post.activity_pub_delete!
        expect(post.reload.activity_pub_scheduled_at).to eq(nil)
        expect(post.activity_pub_published_at).to eq(nil)
      end

      it "returns the outcome of the delete activity" do
        post.stubs(:perform_activity_pub_activity).with(:delete).returns(true)
        expect(post.activity_pub_delete!).to eq(true)
      end
    end
  end

  describe "#activity_pub_schedule!" do
    before { toggle_activity_pub(category, publication_type: "first_post") }

    context "with a published post" do
      before do
        post.custom_fields["activity_pub_published_at"] = Time.now
        post.save_custom_fields(true)
      end

      it "does not attempt to publish" do
        post.expects(:activity_pub_publish!).never
        post.activity_pub_schedule!
      end

      it "returns false" do
        expect(post.activity_pub_schedule!).to eq(false)
      end
    end

    context "with a scheduled post" do
      before do
        post.custom_fields["activity_pub_scheduled_at"] = Time.now
        post.save_custom_fields(true)
      end

      it "does not attempt to publish" do
        post.expects(:activity_pub_publish!).never
        post.activity_pub_schedule!
      end

      it "returns false" do
        expect(post.activity_pub_schedule!).to eq(false)
      end
    end

    context "with a unscheduled unpublished post" do
      context "with followers" do
        let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
        let!(:follow1) do
          Fabricate(
            :discourse_activity_pub_follow,
            follower: follower1,
            followed: category.activity_pub_actor,
          )
        end

        it "attempts to publish" do
          post.expects(:activity_pub_publish!).once
          post.activity_pub_schedule!
        end

        it "returns the outcome of the publish attempt" do
          post.stubs(:activity_pub_publish!).returns(false)
          expect(post.activity_pub_schedule!).to eq(false)
        end
      end
    end
  end

  describe "#activity_pub_unschedule!" do
    before { toggle_activity_pub(category, publication_type: "first_post") }

    context "with a published post" do
      before do
        post.custom_fields["activity_pub_published_at"] = Time.now
        post.save_custom_fields(true)
      end

      it "does not attempt to delete" do
        post.expects(:activity_pub_delete!).never
        post.activity_pub_unschedule!
      end

      it "returns false" do
        expect(post.activity_pub_unschedule!).to eq(false)
      end
    end

    context "with an unscheduled post" do
      it "does not attempt to delete" do
        post.expects(:activity_pub_delete!).never
        post.activity_pub_unschedule!
      end

      it "returns false" do
        expect(post.activity_pub_unschedule!).to eq(false)
      end
    end

    context "with a scheduled unpublished post" do
      before do
        post.custom_fields["activity_pub_scheduled_at"] = Time.now
        post.save_custom_fields(true)
      end

      it "attempts to delete" do
        post.expects(:activity_pub_delete!).once
        post.activity_pub_unschedule!
      end

      it "returns the outcome of the delete attempt" do
        post.expects(:activity_pub_delete!).returns(false)
        expect(post.activity_pub_unschedule!).to eq(false)
      end
    end
  end

  describe "#perform_activity_pub_activity" do
    shared_examples "pre publication delete" do
      it "does not create an activity" do
        perform_delete
        expect(post.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(false)
      end

      it "destroys associated objects" do
        perform_delete
        expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
        expect(DiscourseActivityPubObject.exists?(id: topic.activity_pub_object.id)).to eq(false)
      end

      it "destroys associated activities" do
        perform_delete
        expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(false)
      end

      it "clears associated data" do
        perform_delete
        expect(note.model.custom_fields["activity_pub_scheduled_at"]).to eq(nil)
        expect(note.model.custom_fields["activity_pub_published_at"]).to eq(nil)
        expect(note.model.custom_fields["activity_pub_deleted_at"]).to eq(nil)
      end

      it "clears associated jobs" do
        job1_args = { object_id: create.id, object_type: "DiscourseActivityPubActivity" }
        Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job1_args).once
        job2_args = {
          object_id: topic.activity_pub_object.id,
          object_type: "DiscourseActivityPubCollection",
        }
        Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job2_args).once
        perform_delete
      end

      it "does not send anything for delivery" do
        expect_no_delivery
        perform_delete
      end
    end

    shared_examples "post publication delete" do
      it "creates the right activity" do
        perform_delete
        expect(post.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(true)
      end

      it "does not destroy associated objects" do
        perform_delete
        expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
        expect(DiscourseActivityPubCollection.exists?(id: topic.activity_pub_object.id)).to eq(true)
      end

      it "does not destroy associated activities" do
        perform_delete
        expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
      end
    end

    context "without activty pub enabled on the category" do
      it "does nothing" do
        expect(post.perform_activity_pub_activity(:create)).to eq(nil)
        expect(post.reload.activity_pub_object.present?).to eq(false)
      end
    end

    context "with activity pub enabled on the category" do
      before do
        toggle_activity_pub(category)
        post.reload
      end

      context "with login required" do
        before { SiteSetting.login_required = true }

        it "does nothing" do
          expect(post.perform_activity_pub_activity(:create)).to eq(nil)
          expect(post.reload.activity_pub_object.present?).to eq(false)
        end
      end

      context "with an invalid activity type" do
        it "does nothing" do
          expect(post.perform_activity_pub_activity(:follow)).to eq(nil)
          expect(post.reload.activity_pub_object.present?).to eq(false)
        end
      end

      context "with a whisper" do
        before do
          post.post_type = Post.types[:whisper]
          post.save!
        end

        it "does nothing" do
          expect(post.perform_activity_pub_activity(:create)).to eq(nil)
          expect(post.reload.activity_pub_object.present?).to eq(false)
        end
      end
    end

    context "with first_post enabled on the category" do
      before do
        toggle_activity_pub(category)
        post.reload
      end

      it "acts as the reply user actor" do
        post.perform_activity_pub_activity(:create)
        expect(post.activity_pub_actor.model_id).to eq(category.id)
      end

      context "with create" do
        def perform_create
          post.perform_activity_pub_activity(:create)
          post.reload
        end

        it "creates the right object" do
          perform_create
          expect(post.activity_pub_object.name).to eq(post.activity_pub_name)
          expect(post.activity_pub_object.content).to eq(post.activity_pub_content)
          expect(post.activity_pub_object.reply_to_id).to eq(nil)
        end

        it "creates the right activity" do
          perform_create
          expect(
            post
              .activity_pub_actor
              .activities
              .where(
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Create",
              )
              .exists?,
          ).to eq(true)
        end

        context "when post category has no followers" do
          it "publishes the post's ap objects" do
            freeze_time
            published_at = Time.now.utc.iso8601
            perform_create
            expect(post.activity_pub_published?).to eq(true)
            # rubocop:disable Discourse/TimeEqMatcher
            expect(post.activity_pub_published_at).to eq(published_at)
            expect(post.activity_pub_object.published_at).to eq(published_at)
            expect(post.activity_pub_object.create_activity.published_at).to eq(published_at)
            # rubocop:enable Discourse/TimeEqMatcher
            unfreeze_time
          end
        end

        context "when post category has followers" do
          let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow1) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower1,
              followed: category.activity_pub_actor,
            )
          end
          let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow2) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower2,
              followed: category.activity_pub_actor,
            )
          end

          it "enqueues deliveries to category's followers with appropriate delay" do
            freeze_time
            perform_create
            activity = category.activity_pub_actor.activities.find_by(ap_type: "Create")
            delay = SiteSetting.activity_pub_delivery_delay_minutes.to_i
            job1_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: category.activity_pub_actor.id,
              send_to: follower1.inbox,
            }
            job2_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: category.activity_pub_actor.id,
              send_to: follower2.inbox,
            }
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job1_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job2_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
          end
        end

        context "with replies" do
          before do
            reply.perform_activity_pub_activity(:create)
            reply.reload
          end

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end

        context "when post is deleted" do
          before do
            post.custom_fields["activity_pub_deleted_at"] = Time.now
            post.save_custom_fields(true)
            post.trash!
          end

          it "publishes the post's ap objects" do
            freeze_time
            published_at = Time.now.utc.to_i
            perform_create
            expect(post.activity_pub_published?).to eq(true)
            expect(post.activity_pub_published_at.to_datetime.to_i).to eq_time(published_at)
            expect(post.activity_pub_deleted_at).to eq(nil)
            expect(post.activity_pub_object.published_at.to_datetime.to_i).to eq_time(published_at)
            expect(
              post.activity_pub_object.create_activity.published_at.to_datetime.to_i,
            ).to eq_time(published_at)
            unfreeze_time
          end
        end
      end

      context "with update" do
        let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
        let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

        before { SiteSetting.activity_pub_delivery_delay_minutes = 3 }

        def perform_update
          post.custom_fields["activity_pub_content"] = "Updated content"
          post.perform_activity_pub_activity(:update)
        end

        context "while not published" do
          before { perform_update }

          it "updates the Note content" do
            expect(note.reload.content).to eq("Updated content")
          end

          it "does not create an Update Activity" do
            expect(post.activity_pub_actor.activities.where(ap_type: "Update").exists?).to eq(false)
          end
        end

        context "after publication" do
          before do
            post.acting_user = post.user
            note.model.custom_fields["activity_pub_published_at"] = Time.now
            note.model.save_custom_fields(true)
          end

          it "updates the Note content" do
            perform_update
            expect(note.reload.content).to eq("Updated content")
          end

          it "creates an Update Activity" do
            perform_update
            expect(
              post
                .activity_pub_actor
                .activities
                .where(
                  object_id: post.activity_pub_object.id,
                  object_type: "DiscourseActivityPubObject",
                  ap_type: "Update",
                )
                .exists?,
            ).to eq(true)
          end

          context "when the category has no followers" do
            it "creates multiple published activities" do
              perform_update
              perform_update
              attrs = {
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Update",
              }
              expect(post.activity_pub_actor.activities.where(attrs).size).to eq(2)
            end
          end

          context "when the category has followers" do
            let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow1) do
              Fabricate(
                :discourse_activity_pub_follow,
                follower: follower1,
                followed: category.activity_pub_actor,
              )
            end

            it "does not create multiple unpublished activities" do
              perform_update
              perform_update
              attrs = {
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Update",
                published_at: nil,
              }
              expect(post.activity_pub_actor.activities.where(attrs).size).to eq(1)
            end
          end

          context "when the acting user is different from the post user" do
            let!(:staff) { Fabricate(:moderator) }
            let!(:staff_actor) { Fabricate(:discourse_activity_pub_actor_person, model: staff) }

            before { post.acting_user = staff }

            it "creates an activity with the post user's actor" do
              perform_update
              expect(
                post
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  )
                  .exists?,
              ).to eq(true)
            end
          end
        end

        context "with replies" do
          before { reply.perform_activity_pub_activity(:update) }

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end
      end

      context "with delete" do
        let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
        let!(:create) do
          Fabricate(
            :discourse_activity_pub_activity_create,
            object: note,
            actor: category.activity_pub_actor,
          )
        end

        before { SiteSetting.activity_pub_delivery_delay_minutes = 3 }

        def perform_delete
          post.trash!
          post.perform_activity_pub_activity(:delete)
        end

        context "while in pre publication period" do
          it "does not create an object" do
            perform_delete
            expect(DiscourseActivityPubObject.exists?(model_id: post.id)).to eq(false)
          end

          it "does not create an activity" do
            perform_delete
            expect(post.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(false)
          end

          it "destroys associated objects" do
            perform_delete
            expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
          end

          it "destroys associated activities" do
            perform_delete
            expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(false)
          end

          it "clears associated data" do
            perform_delete
            expect(post.custom_fields["activity_pub_scheduled_at"]).to eq(nil)
            expect(post.custom_fields["activity_pub_published_at"]).to eq(nil)
            expect(post.custom_fields["activity_pub_deleted_at"]).to eq(nil)
          end

          it "clears associated jobs" do
            job_args = { object_id: create.id, object_type: "DiscourseActivityPubActivity" }
            Jobs
              .expects(:cancel_scheduled_job)
              .with(:discourse_activity_pub_deliver, **job_args)
              .once
            perform_delete
          end
        end

        context "after publication" do
          before do
            note.model.custom_fields["activity_pub_published_at"] = Time.now
            note.model.save_custom_fields(true)
          end

          it "creates the right activity" do
            perform_delete
            expect(post.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(true)
          end

          it "does not destroy associated objects" do
            perform_delete
            expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
          end

          it "does not destroy associated activities" do
            perform_delete
            expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
          end

          context "when post category has followers" do
            let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow1) do
              Fabricate(
                :discourse_activity_pub_follow,
                follower: follower1,
                followed: category.activity_pub_actor,
              )
            end
            let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow2) do
              Fabricate(
                :discourse_activity_pub_follow,
                follower: follower2,
                followed: category.activity_pub_actor,
              )
            end

            it "enqueues delivery of activity to category's followers" do
              perform_delete
              activity = category.activity_pub_actor.activities.where(ap_type: "Delete").first
              job1_args = {
                object_id: activity.id,
                object_type: "DiscourseActivityPubActivity",
                from_actor_id: category.activity_pub_actor.id,
                send_to: follower1.inbox,
              }
              job2_args = {
                object_id: activity.id,
                object_type: "DiscourseActivityPubActivity",
                from_actor_id: category.activity_pub_actor.id,
                send_to: follower2.inbox,
              }
              expect(job_enqueued?(job: :discourse_activity_pub_deliver, args: job1_args)).to eq(
                true,
              )
              expect(job_enqueued?(job: :discourse_activity_pub_deliver, args: job2_args)).to eq(
                true,
              )
            end
          end
        end

        context "with replies" do
          before { reply.perform_activity_pub_activity(:update) }

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end
      end

      context "when Article is set as the post object type" do
        before do
          category.activity_pub_actor.post_object_type = "Article"
          category.activity_pub_actor.save!
        end

        context "with create" do
          before do
            post.perform_activity_pub_activity(:create)
            post.reload
          end

          it "creates the right object" do
            expect(post.activity_pub_object.ap_type).to eq("Article")
            expect(post.activity_pub_object.reply_to_id).to eq(nil)
            expect(post.activity_pub_object&.attributed_to_id).to eq(nil)
          end
        end

        context "with update" do
          def perform_update
            post.custom_fields["activity_pub_content"] = "Updated content"
            post.perform_activity_pub_activity(:update)
          end

          context "with an existing Note" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

            it "does not change the object type" do
              perform_update
              expect(post.activity_pub_object.ap_type).to eq("Note")
            end
          end

          context "with an existing Article" do
            let!(:article) { Fabricate(:discourse_activity_pub_object_article, model: post) }

            it "creates the right object" do
              perform_update
              expect(post.reload.activity_pub_object.ap_type).to eq("Article")
            end
          end
        end

        context "with delete" do
          def perform_delete
            post.trash!
            post.perform_activity_pub_activity(:delete)
          end

          context "with an existing Note" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

            it "destroys the Note" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
            end
          end

          context "with an existing Article" do
            let!(:article) { Fabricate(:discourse_activity_pub_object_article, model: post) }

            it "destroys the Article" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: article.id)).to eq(false)
            end
          end
        end
      end
    end

    context "with first_post enabled on the tag" do
      before do
        toggle_activity_pub(tag)
        post.reload
      end

      it "acts as the reply user actor" do
        post.perform_activity_pub_activity(:create)
        expect(post.activity_pub_actor.model_id).to eq(tag.id)
      end

      context "with create" do
        def perform_create
          post.perform_activity_pub_activity(:create)
          post.reload
        end

        it "creates the right object" do
          perform_create
          expect(post.activity_pub_object.name).to eq(post.activity_pub_name)
          expect(post.activity_pub_object.content).to eq(post.activity_pub_content)
          expect(post.activity_pub_object.reply_to_id).to eq(nil)
        end

        it "creates the right activity" do
          perform_create
          expect(
            post
              .activity_pub_actor
              .activities
              .where(
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Create",
              )
              .exists?,
          ).to eq(true)
        end

        context "when tag has followers" do
          let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow1) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower1,
              followed: tag.activity_pub_actor,
            )
          end
          let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow2) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower2,
              followed: tag.activity_pub_actor,
            )
          end

          it "enqueues deliveries to tag's followers with appropriate delay" do
            freeze_time
            perform_create
            activity = tag.activity_pub_actor.activities.find_by(ap_type: "Create")
            delay = SiteSetting.activity_pub_delivery_delay_minutes.to_i
            job1_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: tag.activity_pub_actor.id,
              send_to: follower1.inbox,
            }
            job2_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: tag.activity_pub_actor.id,
              send_to: follower2.inbox,
            }
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job1_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job2_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
          end
        end

        context "with replies" do
          before do
            reply.perform_activity_pub_activity(:create)
            reply.reload
          end

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end
      end

      context "with update" do
        let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
        let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

        before { SiteSetting.activity_pub_delivery_delay_minutes = 3 }

        def perform_update
          post.custom_fields["activity_pub_content"] = "Updated content"
          post.perform_activity_pub_activity(:update)
        end

        context "while not published" do
          before { perform_update }

          it "updates the Note content" do
            expect(note.reload.content).to eq("Updated content")
          end

          it "does not create an Update Activity" do
            expect(post.activity_pub_actor.activities.where(ap_type: "Update").exists?).to eq(false)
          end
        end

        context "after publication" do
          before do
            post.acting_user = post.user
            note.model.custom_fields["activity_pub_published_at"] = Time.now
            note.model.save_custom_fields(true)
          end

          it "updates the Note content" do
            perform_update
            expect(note.reload.content).to eq("Updated content")
          end

          it "creates an Update Activity" do
            perform_update
            expect(
              post
                .activity_pub_actor
                .activities
                .where(
                  object_id: post.activity_pub_object.id,
                  object_type: "DiscourseActivityPubObject",
                  ap_type: "Update",
                )
                .exists?,
            ).to eq(true)
          end

          context "when the tag has no followers" do
            it "creates multiple published activities" do
              perform_update
              perform_update
              attrs = {
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Update",
              }
              expect(post.activity_pub_actor.activities.where(attrs).size).to eq(2)
            end
          end

          context "when the tag has followers" do
            let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow1) do
              Fabricate(
                :discourse_activity_pub_follow,
                follower: follower1,
                followed: tag.activity_pub_actor,
              )
            end

            it "doe not create multiple unpublished activities" do
              perform_update
              perform_update
              attrs = {
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Update",
                published_at: nil,
              }
              expect(post.activity_pub_actor.activities.where(attrs).size).to eq(1)
            end
          end

          context "when the acting user is different from the post user" do
            let!(:staff) { Fabricate(:moderator) }
            let!(:staff_actor) { Fabricate(:discourse_activity_pub_actor_person, model: staff) }

            before { post.acting_user = staff }

            it "creates an activity with the post user's actor" do
              perform_update
              expect(
                post
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  )
                  .exists?,
              ).to eq(true)
            end

            it "doesn't create a activity with the acting user's actor" do
              perform_update
              expect(
                staff
                  .reload
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  )
                  .exists?,
              ).to eq(false)
            end
          end
        end

        context "with replies" do
          before { reply.perform_activity_pub_activity(:update) }

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end
      end

      context "with delete" do
        let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
        let!(:create) do
          Fabricate(
            :discourse_activity_pub_activity_create,
            object: note,
            actor: tag.activity_pub_actor,
          )
        end

        before { SiteSetting.activity_pub_delivery_delay_minutes = 3 }

        def perform_delete
          post.trash!
          post.perform_activity_pub_activity(:delete)
        end

        context "while in pre publication period" do
          it "does not create an object" do
            perform_delete
            expect(DiscourseActivityPubObject.exists?(model_id: post.id)).to eq(false)
          end

          it "does not create an activity" do
            perform_delete
            expect(post.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(false)
          end

          it "destroys associated objects" do
            perform_delete
            expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
          end

          it "destroys associated activities" do
            perform_delete
            expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(false)
          end

          it "clears associated data" do
            perform_delete
            expect(post.custom_fields["activity_pub_scheduled_at"]).to eq(nil)
            expect(post.custom_fields["activity_pub_published_at"]).to eq(nil)
            expect(post.custom_fields["activity_pub_deleted_at"]).to eq(nil)
          end

          it "clears associated jobs" do
            job_args = { object_id: create.id, object_type: "DiscourseActivityPubActivity" }
            Jobs
              .expects(:cancel_scheduled_job)
              .with(:discourse_activity_pub_deliver, **job_args)
              .once
            perform_delete
          end
        end

        context "after publication" do
          before do
            note.model.custom_fields["activity_pub_published_at"] = Time.now
            note.model.save_custom_fields(true)
          end

          it "creates the right activity" do
            perform_delete
            expect(post.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(true)
          end

          it "does not destroy associated objects" do
            perform_delete
            expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
          end

          it "does not destroy associated activities" do
            perform_delete
            expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
          end

          context "when tag has followers" do
            let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow1) do
              Fabricate(
                :discourse_activity_pub_follow,
                follower: follower1,
                followed: tag.activity_pub_actor,
              )
            end
            let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow2) do
              Fabricate(
                :discourse_activity_pub_follow,
                follower: follower2,
                followed: tag.activity_pub_actor,
              )
            end

            it "enqueues delivery of activity to tag's followers" do
              perform_delete
              activity = tag.activity_pub_actor.activities.where(ap_type: "Delete").first
              job1_args = {
                object_id: activity.id,
                object_type: "DiscourseActivityPubActivity",
                from_actor_id: tag.activity_pub_actor.id,
                send_to: follower1.inbox,
              }
              job2_args = {
                object_id: activity.id,
                object_type: "DiscourseActivityPubActivity",
                from_actor_id: tag.activity_pub_actor.id,
                send_to: follower2.inbox,
              }
              expect(job_enqueued?(job: :discourse_activity_pub_deliver, args: job1_args)).to eq(
                true,
              )
              expect(job_enqueued?(job: :discourse_activity_pub_deliver, args: job2_args)).to eq(
                true,
              )
            end
          end
        end

        context "with replies" do
          before { reply.perform_activity_pub_activity(:update) }

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end
      end

      context "when Article is set as the post object type" do
        before do
          tag.activity_pub_actor.post_object_type = "Article"
          tag.activity_pub_actor.save!
        end

        context "with create" do
          before do
            post.perform_activity_pub_activity(:create)
            post.reload
          end

          it "creates the right object" do
            expect(post.activity_pub_object.ap_type).to eq("Article")
            expect(post.activity_pub_object.reply_to_id).to eq(nil)
            expect(post.activity_pub_object&.attributed_to_id).to eq(nil)
          end
        end

        context "with update" do
          def perform_update
            post.custom_fields["activity_pub_content"] = "Updated content"
            post.perform_activity_pub_activity(:update)
          end

          context "with an existing Note" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

            it "does not change the object type" do
              perform_update
              expect(post.activity_pub_object.ap_type).to eq("Note")
            end
          end

          context "with an existing Article" do
            let!(:article) { Fabricate(:discourse_activity_pub_object_article, model: post) }

            it "creates the right object" do
              perform_update
              expect(post.reload.activity_pub_object.ap_type).to eq("Article")
            end
          end
        end

        context "with delete" do
          def perform_delete
            post.trash!
            post.perform_activity_pub_activity(:delete)
          end

          context "with an existing Note" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

            it "destroys the Note" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
            end
          end

          context "with an existing Article" do
            let!(:article) { Fabricate(:discourse_activity_pub_object_article, model: post) }

            it "destroys the Article" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: article.id)).to eq(false)
            end
          end
        end
      end
    end

    context "with first_post enabled on the tag and the category" do
      before do
        toggle_activity_pub(tag)
        toggle_activity_pub(category)
        post.reload
      end

      context "with create" do
        def perform_create
          post.perform_activity_pub_activity(:create)
          post.reload
        end

        context "when the tag and category have different followers" do
          let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow1) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower1,
              followed: tag.activity_pub_actor,
            )
          end
          let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow2) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower2,
              followed: category.activity_pub_actor,
            )
          end

          it "enqueues deliveries to both the tag and category's followers" do
            freeze_time
            perform_create
            activity = tag.activity_pub_actor.activities.find_by(ap_type: "Create")
            delay = SiteSetting.activity_pub_delivery_delay_minutes.to_i
            job1_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: tag.activity_pub_actor.id,
              send_to: follower1.inbox,
            }
            job2_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: category.activity_pub_actor.id,
              send_to: follower2.inbox,
            }
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job1_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job2_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
          end
        end

        context "when an actor is following both the tag and the category" do
          let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow1) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower1,
              followed: tag.activity_pub_actor,
            )
          end
          let!(:follow2) do
            Fabricate(
              :discourse_activity_pub_follow,
              follower: follower1,
              followed: category.activity_pub_actor,
            )
          end

          it "enqueues a single delivery to the follower as the tag actor" do
            freeze_time
            perform_create
            activity = tag.activity_pub_actor.activities.find_by(ap_type: "Create")
            delay = SiteSetting.activity_pub_delivery_delay_minutes.to_i
            job1_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: tag.activity_pub_actor.id,
              send_to: follower1.inbox,
            }
            job2_args = {
              object_id: activity.id,
              object_type: "DiscourseActivityPubActivity",
              from_actor_id: category.activity_pub_actor.id,
              send_to: follower1.inbox,
            }
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job1_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(true)
            expect(
              job_enqueued?(
                job: :discourse_activity_pub_deliver,
                args: job2_args,
                at: delay.minutes.from_now,
              ),
            ).to eq(false)
          end
        end
      end
    end

    context "with full_topic enabled on the category" do
      before do
        toggle_activity_pub(category, publication_type: "full_topic")
        DiscourseActivityPub::ActorHandler.update_or_create_actor(post.user)
        DiscourseActivityPub::ActorHandler.update_or_create_actor(reply.user)
      end

      context "without a topic collection" do
        it "does not perform the activity" do
          expect(post.perform_activity_pub_activity(:create)).to eq(nil)
          expect(DiscourseActivityPubActivity.exists?(ap_type: "Create")).to eq(false)
        end
      end

      context "with a topic collection" do
        before { post.topic.create_activity_pub_collection! }

        it "acts as the post user actor" do
          post.perform_activity_pub_activity(:create)
          post.reload
          expect(post.activity_pub_actor.model_id).to eq(post.user_id)
        end

        context "with the first post" do
          context "with create" do
            def perform_create
              post.perform_activity_pub_activity(:create)
              post.reload
            end

            it "creates the right object" do
              perform_create
              expect(post.activity_pub_object&.content).to eq(post.activity_pub_content)
              expect(post.activity_pub_object&.reply_to_id).to eq(nil)
              expect(post.activity_pub_object&.attributed_to_id).to eq(
                post.user.activity_pub_actor.ap_id,
              )
            end

            it "creates the right activity" do
              perform_create
              expect(
                post
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Create",
                  )
                  .exists?,
              ).to eq(true)
            end

            it "includes the object in the topic's object collection" do
              perform_create
              expect(post.activity_pub_object.ap_id).to eq(
                topic.activity_pub_object.objects_collection.items.first.ap_id,
              )
            end

            it "includes the activity in the topic's activity collection" do
              perform_create
              expect(post.activity_pub_actor.activities.first.ap_id).to eq(
                topic.activity_pub_object.activities_collection.items.first.ap_id,
              )
            end

            context "with followers" do
              let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
              let!(:follow1) do
                Fabricate(
                  :discourse_activity_pub_follow,
                  follower: follower1,
                  followed: category.activity_pub_actor,
                )
              end

              it "sends the activity for delayed delivery" do
                expect_delivery(
                  actor: topic.activity_pub_actor,
                  object_type: "Create",
                  delay: SiteSetting.activity_pub_delivery_delay_minutes.to_i,
                )
                perform_create
              end
            end
          end

          context "with delete" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            context "when post is trashed" do
              def perform_delete
                topic.trash!
                post.trash!
                post.reload.perform_activity_pub_activity(:delete)
              end

              context "while in pre publication period" do
                include_examples "pre publication delete"
              end

              context "after publication" do
                before do
                  note.model.custom_fields["activity_pub_published_at"] = Time.now
                  note.model.save_custom_fields(true)
                end

                include_examples "post publication delete"
              end
            end

            context "when post is destroyed" do
              def perform_delete
                topic.destroy!
                post.destroy!
                post.perform_activity_pub_activity(:delete)
              end

              context "while in pre publication period" do
                include_examples "pre publication delete"
              end

              context "after publication" do
                before do
                  note.model.custom_fields["activity_pub_published_at"] = Time.now
                  note.model.save_custom_fields(true)
                end

                include_examples "post publication delete"
              end
            end
          end

          context "with update" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            def perform_update
              post.custom_fields["activity_pub_content"] = "Updated content"
              post.perform_activity_pub_activity(:update)
            end

            context "while not published" do
              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "does not create an Update Activity" do
                perform_update
                expect(post.activity_pub_actor.activities.where(ap_type: "Update").exists?).to eq(
                  false,
                )
              end

              it "does not send anything for delivery" do
                expect_no_delivery
                perform_update
              end
            end

            context "after publication" do
              before do
                post.acting_user = post.user
                note.model.custom_fields["activity_pub_published_at"] = Time.now
                note.model.save_custom_fields(true)
              end

              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "creates an Update Activity" do
                perform_update
                expect(
                  post
                    .activity_pub_actor
                    .activities
                    .where(
                      object_id: post.activity_pub_object.id,
                      object_type: "DiscourseActivityPubObject",
                      ap_type: "Update",
                    )
                    .exists?,
                ).to eq(true)
              end

              context "with no followers" do
                it "creates multiple published activities" do
                  perform_update
                  perform_update
                  attrs = {
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  }
                  expect(post.activity_pub_actor.activities.where(attrs).size).to eq(2)
                end
              end

              context "with followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: category.activity_pub_actor,
                  )
                end

                it "does not create multiple unpublished activities" do
                  perform_update
                  perform_update
                  attrs = {
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                    published_at: nil,
                  }
                  expect(post.activity_pub_actor.activities.where(attrs).size).to eq(1)
                end

                it "sends the activity as the category actor for delivery without delay" do
                  expect_delivery(actor: category.activity_pub_actor, object_type: "Update")
                  perform_update
                end
              end

              context "when the acting user is different from the post user" do
                let!(:staff) { Fabricate(:moderator) }

                before { post.acting_user = staff }

                it "creates an activity with the acting user's actor" do
                  perform_update
                  expect(
                    staff
                      .activity_pub_actor
                      .activities
                      .where(
                        object_id: post.activity_pub_object.id,
                        object_type: "DiscourseActivityPubObject",
                        ap_type: "Update",
                      )
                      .exists?,
                  ).to eq(true)
                end

                it "doesnt create an activity with the post user's actor" do
                  perform_update
                  expect(
                    post
                      .activity_pub_actor
                      .activities
                      .where(
                        object_id: post.activity_pub_object.id,
                        object_type: "DiscourseActivityPubObject",
                        ap_type: "Update",
                      )
                      .exists?,
                  ).to eq(false)
                end
              end
            end
          end
        end

        context "with replies" do
          let!(:post_note) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post,
              collection_id: topic.activity_pub_object.id,
              attributed_to: post.activity_pub_actor,
            )
          end

          context "with create" do
            def perform_create
              reply.perform_activity_pub_activity(:create)
              reply.reload
            end

            it "creates the right object" do
              perform_create
              expect(reply.activity_pub_object&.content).to eq(reply.activity_pub_content)
              expect(reply.activity_pub_object&.reply_to_id).to eq(post_note.ap_id)
              expect(reply.activity_pub_object&.collection_id).to eq(topic.activity_pub_object.id)
            end

            it "creates the right activity" do
              perform_create
              expect(
                reply
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: reply.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Create",
                  )
                  .exists?,
              ).to eq(true)
            end

            context "with topic publication" do
              context "when the category has followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: category.activity_pub_actor,
                  )
                end

                it "sends the activity for delayed delivery" do
                  expect_delivery(
                    actor: topic.activity_pub_actor,
                    object_type: "Create",
                    delay: SiteSetting.activity_pub_delivery_delay_minutes.to_i,
                  )
                  perform_create
                end
              end
            end

            context "after topic publication" do
              before do
                post.custom_fields["activity_pub_published_at"] = Time.now
                post.save_custom_fields(true)
              end

              context "when the topic has a remote contributor" do
                before { post.activity_pub_actor.update(local: false) }

                it "sends to remote contributors for delivery without delay" do
                  expect_delivery(
                    actor: topic.activity_pub_actor,
                    object_type: "Create",
                    recipient_ids: [post.activity_pub_actor.id],
                  )
                  perform_create
                end

                context "when the category has followers" do
                  let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                  let!(:follow1) do
                    Fabricate(
                      :discourse_activity_pub_follow,
                      follower: follower1,
                      followed: category.activity_pub_actor,
                    )
                  end

                  it "sends to followers and remote contributors for delivery without delay" do
                    expect_delivery(
                      actor: topic.activity_pub_actor,
                      object_type: "Create",
                      recipient_ids: [follower1.id] + [post.activity_pub_actor.id],
                    )
                    perform_create
                  end
                end
              end
            end
          end

          context "with update" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: reply) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            def perform_update
              reply.custom_fields["activity_pub_content"] = "Updated content"
              reply.perform_activity_pub_activity(:update)
            end

            context "while not published" do
              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "does not create an Update Activity" do
                perform_update
                expect(reply.activity_pub_actor.activities.where(ap_type: "Update").exists?).to eq(
                  false,
                )
              end

              it "does not send anything for delivery" do
                expect_no_delivery
                perform_update
              end
            end

            context "after publication" do
              before do
                post.custom_fields["activity_pub_published_at"] = Time.now
                post.save_custom_fields(true)
                reply.custom_fields["activity_pub_published_at"] = Time.now
                reply.save_custom_fields(true)
              end

              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "creates an Update Activity" do
                perform_update
                expect(
                  reply
                    .activity_pub_actor
                    .activities
                    .where(
                      object_id: reply.activity_pub_object.id,
                      object_type: "DiscourseActivityPubObject",
                      ap_type: "Update",
                    )
                    .exists?,
                ).to eq(true)
              end

              it "doesn't create multiple unpublished activities" do
                perform_update
                expect(
                  reply
                    .activity_pub_actor
                    .activities
                    .where(
                      object_id: reply.activity_pub_object.id,
                      object_type: "DiscourseActivityPubObject",
                      ap_type: "Update",
                    )
                    .size,
                ).to eq(1)
              end

              it "creates multiple published activities" do
                perform_update

                attrs = {
                  object_id: reply.activity_pub_object.id,
                  object_type: "DiscourseActivityPubObject",
                  ap_type: "Update",
                }
                reply.activity_pub_actor.activities.where(attrs).update_all(published_at: Time.now)

                perform_update

                expect(reply.activity_pub_actor.activities.where(attrs).size).to eq(2)
              end

              context "with followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: category.activity_pub_actor,
                  )
                end

                it "sends the activity as the category actor for delivery without delay" do
                  expect_delivery(actor: category.activity_pub_actor, object_type: "Update")
                  perform_update
                end
              end
            end
          end

          context "with delete" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: reply) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            def perform_delete
              reply.delete
              reply.perform_activity_pub_activity(:delete)
            end

            context "while in pre publication period" do
              it "does not create an object" do
                perform_delete
                expect(DiscourseActivityPubObject.exists?(model_id: reply.id)).to eq(false)
              end

              it "does not create an activity" do
                perform_delete
                expect(reply.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(
                  false,
                )
              end

              it "destroys associated objects" do
                perform_delete
                expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
              end

              it "destroys associated activities" do
                perform_delete
                expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(false)
              end

              it "clears associated data" do
                perform_delete
                expect(note.model.custom_fields["activity_pub_scheduled_at"]).to eq(nil)
                expect(note.model.custom_fields["activity_pub_published_at"]).to eq(nil)
                expect(note.model.custom_fields["activity_pub_deleted_at"]).to eq(nil)
              end

              it "clears associated jobs" do
                job_args = { object_id: create.id, object_type: "DiscourseActivityPubActivity" }
                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_activity_pub_deliver, **job_args)
                  .once
                perform_delete
              end

              it "does not send anything for delivery" do
                expect_no_delivery
                perform_delete
              end
            end

            context "after publication" do
              before do
                post.custom_fields["activity_pub_published_at"] = Time.now
                post.save_custom_fields(true)
                reply.custom_fields["activity_pub_published_at"] = Time.now
                reply.save_custom_fields(true)
              end

              it "creates the right activity" do
                perform_delete
                expect(reply.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(
                  true,
                )
              end

              it "does not destroy associated objects" do
                perform_delete
                expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
              end

              it "does not destroy associated activities" do
                perform_delete
                expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
              end

              context "with followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: category.activity_pub_actor,
                  )
                end

                it "sends the activity as the category actor for delivery without delay" do
                  expect_delivery(actor: category.activity_pub_actor, object_type: "Delete")
                  perform_delete
                end
              end
            end
          end

          context "with no reply_to_post_number" do
            before do
              reply.reply_to_post_number = nil
              reply.save!
              reply.perform_activity_pub_activity(:create)
              reply.reload
            end

            it "creates the right object" do
              expect(reply.activity_pub_object&.content).to eq(reply.activity_pub_content)
              expect(reply.activity_pub_object&.reply_to_id).to eq(post_note.ap_id)
            end
          end
        end
      end
    end

    context "with full_topic enabled on the tag" do
      before do
        toggle_activity_pub(tag, publication_type: "full_topic")
        DiscourseActivityPub::ActorHandler.update_or_create_actor(post.user)
        DiscourseActivityPub::ActorHandler.update_or_create_actor(reply.user)
      end

      context "without a topic collection" do
        it "does not perform the activity" do
          expect(post.perform_activity_pub_activity(:create)).to eq(nil)
          expect(DiscourseActivityPubActivity.exists?(ap_type: "Create")).to eq(false)
        end
      end

      context "with a topic collection" do
        before { post.topic.create_activity_pub_collection! }

        it "acts as the post user actor" do
          post.perform_activity_pub_activity(:create)
          post.reload
          expect(post.activity_pub_actor.model_id).to eq(post.user_id)
        end

        context "with the first post" do
          context "with create" do
            def perform_create
              post.perform_activity_pub_activity(:create)
              post.reload
            end

            it "creates the right object" do
              perform_create
              expect(post.activity_pub_object&.content).to eq(post.activity_pub_content)
              expect(post.activity_pub_object&.reply_to_id).to eq(nil)
              expect(post.activity_pub_object&.attributed_to_id).to eq(
                post.user.activity_pub_actor.ap_id,
              )
            end

            it "creates the right activity" do
              perform_create
              expect(
                post
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Create",
                  )
                  .exists?,
              ).to eq(true)
            end

            it "includes the object in the topic's object collection" do
              perform_create
              expect(post.activity_pub_object.ap_id).to eq(
                topic.activity_pub_object.objects_collection.items.first.ap_id,
              )
            end

            it "includes the activity in the topic's activity collection" do
              perform_create
              expect(post.activity_pub_actor.activities.first.ap_id).to eq(
                topic.activity_pub_object.activities_collection.items.first.ap_id,
              )
            end

            context "with followers" do
              let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
              let!(:follow1) do
                Fabricate(
                  :discourse_activity_pub_follow,
                  follower: follower1,
                  followed: tag.activity_pub_actor,
                )
              end

              it "sends activity as the topic actor for delayed delivery" do
                expect_delivery(
                  actor: topic.activity_pub_actor,
                  object_type: "Create",
                  delay: SiteSetting.activity_pub_delivery_delay_minutes.to_i,
                )
                perform_create
              end
            end
          end

          context "with delete" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
            let!(:create) do
              Fabricate(
                :discourse_activity_pub_activity_create,
                actor: post.activity_pub_actor,
                object: note,
              )
            end

            context "when post is trashed" do
              def perform_delete
                post.trash!
                topic.trash!
                post.reload.perform_activity_pub_activity(:delete)
              end

              context "while in pre publication period" do
                include_examples "pre publication delete"
              end

              context "after publication" do
                before do
                  note.model.custom_fields["activity_pub_published_at"] = Time.now
                  note.model.save_custom_fields(true)
                end

                include_examples "post publication delete"
              end
            end

            context "when post is destroyed" do
              def perform_delete
                post.destroy!
                topic.destroy!
                post.perform_activity_pub_activity(:delete)
              end

              context "while in pre publication period" do
                include_examples "pre publication delete"
              end

              context "after publication" do
                before do
                  note.model.custom_fields["activity_pub_published_at"] = Time.now
                  note.model.save_custom_fields(true)
                end

                include_examples "post publication delete"
              end
            end
          end

          context "with update" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            def perform_update
              post.custom_fields["activity_pub_content"] = "Updated content"
              post.perform_activity_pub_activity(:update)
            end

            context "while not published" do
              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "does not create an Update Activity" do
                perform_update
                expect(post.activity_pub_actor.activities.where(ap_type: "Update").exists?).to eq(
                  false,
                )
              end

              it "does not send anything for delivery" do
                expect_no_delivery
                perform_update
              end
            end

            context "after publication" do
              before do
                post.acting_user = post.user
                note.model.custom_fields["activity_pub_published_at"] = Time.now
                note.model.save_custom_fields(true)
              end

              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "creates an Update Activity" do
                perform_update
                expect(
                  post
                    .activity_pub_actor
                    .activities
                    .where(
                      object_id: post.activity_pub_object.id,
                      object_type: "DiscourseActivityPubObject",
                      ap_type: "Update",
                    )
                    .exists?,
                ).to eq(true)
              end

              context "when the tag has no followers" do
                it "creates multiple published activities" do
                  perform_update
                  perform_update
                  attrs = {
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  }
                  expect(post.activity_pub_actor.activities.where(attrs).size).to eq(2)
                end
              end

              context "when the tag has followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: tag.activity_pub_actor,
                  )
                end

                it "does not create multiple unpublished activities" do
                  perform_update
                  perform_update
                  attrs = {
                    object_id: post.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                    published_at: nil,
                  }
                  expect(post.activity_pub_actor.activities.where(attrs).size).to eq(1)
                end

                it "sends the activity as the tag actor for delivery without delay" do
                  expect_delivery(actor: tag.activity_pub_actor, object_type: "Update")
                  perform_update
                end
              end

              context "when the acting user is different from the post user" do
                let!(:staff) { Fabricate(:moderator) }

                before { post.acting_user = staff }

                it "creates an activity with the acting user's actor" do
                  perform_update
                  expect(
                    staff
                      .activity_pub_actor
                      .activities
                      .where(
                        object_id: post.activity_pub_object.id,
                        object_type: "DiscourseActivityPubObject",
                        ap_type: "Update",
                      )
                      .exists?,
                  ).to eq(true)
                end

                it "doesnt create an activity with the post user's actor" do
                  perform_update
                  expect(
                    post
                      .activity_pub_actor
                      .activities
                      .where(
                        object_id: post.activity_pub_object.id,
                        object_type: "DiscourseActivityPubObject",
                        ap_type: "Update",
                      )
                      .exists?,
                  ).to eq(false)
                end
              end
            end
          end
        end

        context "with replies" do
          let!(:post_note) do
            Fabricate(
              :discourse_activity_pub_object_note,
              model: post,
              collection_id: topic.activity_pub_object.id,
              attributed_to: post.activity_pub_actor,
            )
          end

          context "with create" do
            def perform_create
              reply.perform_activity_pub_activity(:create)
              reply.reload
            end

            it "creates the right object" do
              perform_create
              expect(reply.activity_pub_object&.content).to eq(reply.activity_pub_content)
              expect(reply.activity_pub_object&.reply_to_id).to eq(post_note.ap_id)
              expect(reply.activity_pub_object&.collection_id).to eq(topic.activity_pub_object.id)
            end

            it "creates the right activity" do
              perform_create
              expect(
                reply
                  .activity_pub_actor
                  .activities
                  .where(
                    object_id: reply.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Create",
                  )
                  .exists?,
              ).to eq(true)
            end

            context "with topic publication" do
              context "when the tag has followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: tag.activity_pub_actor,
                  )
                end

                it "enqueues the activity for delivery" do
                  expect_delivery(actor: topic.activity_pub_actor, object_type: "Create")
                  perform_create
                end
              end
            end

            context "after topic publication" do
              before do
                post.custom_fields["activity_pub_published_at"] = Time.now
                post.save_custom_fields(true)
              end

              context "when the topic has a remote contributor" do
                before { post.activity_pub_actor.update(local: false) }

                it "sends to remote contributors for delivery without delay" do
                  expect_delivery(
                    actor: topic.activity_pub_actor,
                    object_type: "Create",
                    recipient_ids: [post.activity_pub_actor.id],
                  )
                  perform_create
                end

                context "when the tag has followers" do
                  let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                  let!(:follow1) do
                    Fabricate(
                      :discourse_activity_pub_follow,
                      follower: follower1,
                      followed: tag.activity_pub_actor,
                    )
                  end

                  it "sends to followers and remote contributors for delivery without delay" do
                    expect_delivery(
                      actor: topic.activity_pub_actor,
                      object_type: "Create",
                      recipient_ids: [follower1.id] + [post.activity_pub_actor.id],
                    )
                    perform_create
                  end
                end
              end
            end
          end

          context "with update" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: reply) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            def perform_update
              reply.custom_fields["activity_pub_content"] = "Updated content"
              reply.perform_activity_pub_activity(:update)
            end

            context "while not published" do
              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "does not create an Update Activity" do
                perform_update
                expect(reply.activity_pub_actor.activities.where(ap_type: "Update").exists?).to eq(
                  false,
                )
              end

              it "does not send anything for delivery" do
                expect_no_delivery
                perform_update
              end
            end

            context "after publication" do
              before do
                post.custom_fields["activity_pub_published_at"] = Time.now
                post.save_custom_fields(true)
                reply.custom_fields["activity_pub_published_at"] = Time.now
                reply.save_custom_fields(true)
              end

              it "updates the Note content" do
                perform_update
                expect(note.reload.content).to eq("Updated content")
              end

              it "creates an Update Activity" do
                perform_update
                expect(
                  reply
                    .activity_pub_actor
                    .activities
                    .where(
                      object_id: reply.activity_pub_object.id,
                      object_type: "DiscourseActivityPubObject",
                      ap_type: "Update",
                    )
                    .exists?,
                ).to eq(true)
              end

              context "with no followers" do
                it "creates multiple published activities" do
                  perform_update
                  perform_update
                  attrs = {
                    object_id: reply.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                  }
                  expect(reply.activity_pub_actor.activities.where(attrs).size).to eq(2)
                end
              end

              context "with followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: tag.activity_pub_actor,
                  )
                end

                it "does not create multiple unpublished activities" do
                  perform_update
                  perform_update
                  attrs = {
                    object_id: reply.activity_pub_object.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: "Update",
                    published_at: nil,
                  }
                  expect(reply.activity_pub_actor.activities.where(attrs).size).to eq(1)
                end

                it "sends the activity as the tag actor for delivery without delay" do
                  expect_delivery(actor: tag.activity_pub_actor, object_type: "Update")
                  perform_update
                end
              end
            end
          end

          context "with delete" do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: reply) }
            let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

            def perform_delete
              reply.delete
              reply.perform_activity_pub_activity(:delete)
            end

            context "while in pre publication period" do
              it "does not create an object" do
                perform_delete
                expect(DiscourseActivityPubObject.exists?(model_id: reply.id)).to eq(false)
              end

              it "does not create an activity" do
                perform_delete
                expect(reply.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(
                  false,
                )
              end

              it "destroys associated objects" do
                perform_delete
                expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
              end

              it "destroys associated activities" do
                perform_delete
                expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(false)
              end

              it "clears associated data" do
                perform_delete
                expect(note.model.custom_fields["activity_pub_scheduled_at"]).to eq(nil)
                expect(note.model.custom_fields["activity_pub_published_at"]).to eq(nil)
                expect(note.model.custom_fields["activity_pub_deleted_at"]).to eq(nil)
              end

              it "clears associated jobs" do
                job_args = { object_id: create.id, object_type: "DiscourseActivityPubActivity" }
                Jobs
                  .expects(:cancel_scheduled_job)
                  .with(:discourse_activity_pub_deliver, **job_args)
                  .once
                perform_delete
              end

              it "does not send anything for delivery" do
                expect_no_delivery
                perform_delete
              end
            end

            context "after publication" do
              before do
                post.custom_fields["activity_pub_published_at"] = Time.now
                post.save_custom_fields(true)
                reply.custom_fields["activity_pub_published_at"] = Time.now
                reply.save_custom_fields(true)
              end

              it "creates the right activity" do
                perform_delete
                expect(reply.activity_pub_actor.activities.where(ap_type: "Delete").exists?).to eq(
                  true,
                )
              end

              it "does not destroy associated objects" do
                perform_delete
                expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
              end

              it "does not destroy associated activities" do
                perform_delete
                expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
              end

              context "when the tag has followers" do
                let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
                let!(:follow1) do
                  Fabricate(
                    :discourse_activity_pub_follow,
                    follower: follower1,
                    followed: tag.activity_pub_actor,
                  )
                end

                it "sends the activity as the post actor for delivery without delay" do
                  expect_delivery(actor: tag.activity_pub_actor, object_type: "Delete")
                  perform_delete
                end
              end
            end
          end

          context "with no reply_to_post_number" do
            before do
              reply.reply_to_post_number = nil
              reply.save!
              reply.perform_activity_pub_activity(:create)
              reply.reload
            end

            it "creates the right object" do
              expect(reply.activity_pub_object&.content).to eq(reply.activity_pub_content)
              expect(reply.activity_pub_object&.reply_to_id).to eq(post_note.ap_id)
            end
          end
        end
      end
    end
  end
end
