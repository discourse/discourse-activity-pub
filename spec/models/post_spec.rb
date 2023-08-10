# frozen_string_literal: true

RSpec.describe Post do
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:reply) { Fabricate(:post, topic: topic, post_number: 2, reply_to_post_number: 1) }

  it { is_expected.to have_one(:activity_pub_object) }

  describe "#activity_pub_enabled" do
    context "with activity pub plugin enabled" do
      context "with activity pub set to first post on category" do
        before do
          toggle_activity_pub(category, callbacks: true)
        end

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
          toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
          topic.create_activity_pub_collection!
        end

        context "when first post in topic" do
          it { expect(post.activity_pub_enabled).to eq(true) }
        end

        context "when not first post in topic" do
          it { expect(reply.activity_pub_enabled).to eq(true) }
        end
      end
    end

    context "with activity pub plugin disabled" do
      it { expect(post.activity_pub_enabled).to eq(false) }
    end
  end

  describe "#activity_pub_publish_state" do
    let(:group) { Fabricate(:group) }

    before do
      category.update(reviewable_by_group_id: group.id)
    end

    context "with activity pub ready on category" do
      before do
        toggle_activity_pub(category, callbacks: true)
      end

      it "publishes status only to staff and category moderators" do
        message = MessageBus.track_publish("/activity-pub") do
          post.activity_pub_publish_state
        end.first
        expect(message.group_ids).to eq(
          [Group::AUTO_GROUPS[:staff], category.reviewable_by_group_id]
        )
      end

      context "with status changes" do
        before do
          freeze_time

          post.custom_fields['activity_pub_published_at'] = 2.days.ago.iso8601(3)
          post.custom_fields['activity_pub_deleted_at'] = Time.now.iso8601(3)
          post.save_custom_fields(true)
        end

        it "publishes the correct status" do
          message = MessageBus.track_publish("/activity-pub") do
            post.activity_pub_publish_state
          end.first
          expect(message.data[:model][:id]).to eq(post.id)
          expect(message.data[:model][:type]).to eq("post")
          expect(message.data[:model][:published_at]).to eq(2.days.ago.iso8601(3))
          expect(message.data[:model][:deleted_at]).to eq(Time.now.iso8601(3))
        end
      end
    end
  end

  describe "#perform_activity_pub_activity" do
    context "without activty pub enabled on the category" do
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

    context "with first_post enabled on the category" do
      before do
        toggle_activity_pub(category, callbacks: true)
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
          expect(
            post.activity_pub_object.content
          ).to eq(post.activity_pub_content)
          expect(
            post.activity_pub_object.reply_to_id
          ).to eq(nil)
        end

        it "creates the right activity" do
          perform_create
          expect(
             post.activity_pub_actor.activities.where(
               object_id: post.activity_pub_object.id,
               object_type: 'DiscourseActivityPubObject',
               ap_type: 'Create'
            ).exists?
          ).to eq(true)
        end

        context "when post category has followers" do
          let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category.activity_pub_actor) }
          let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
          let!(:follow2) { Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: category.activity_pub_actor) }

          it "enqueues deliveries to category's followers with appropriate delay" do
            freeze_time
            perform_create
            activity = category.activity_pub_actor.activities.find_by(ap_type: "Create")
            delay = SiteSetting.activity_pub_delivery_delay_minutes.to_i
            job1_args = {
              object_id: activity.id,
              object_type: 'DiscourseActivityPubActivity',
              from_actor_id: category.activity_pub_actor.id,
              to_actor_id: follower1.id
            }
            job2_args = {
              object_id: activity.id,
              object_type: 'DiscourseActivityPubActivity',
              from_actor_id: category.activity_pub_actor.id,
              to_actor_id: follower2.id
            }
            expect(
              job_enqueued?(job: :discourse_activity_pub_deliver, args: job1_args, at: delay.minutes.from_now)
            ).to eq(true)
            expect(
              job_enqueued?(job: :discourse_activity_pub_deliver, args: job2_args, at: delay.minutes.from_now)
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

        before do
          SiteSetting.activity_pub_delivery_delay_minutes = 3
        end

        def perform_update
          post.custom_fields['activity_pub_content'] = "Updated content"
          post.perform_activity_pub_activity(:update)
        end

        context "while not published" do
          before do
            perform_update
          end

          it "updates the Note content" do
            expect(note.reload.content).to eq("Updated content")
          end

          it "does not create an Update Activity" do
            expect(
               post.activity_pub_actor.activities.where(
                 ap_type: 'Update'
              ).exists?
            ).to eq(false)
          end
        end

        context "after publication" do
          before do
            note.model.custom_fields['activity_pub_published_at'] = Time.now
            note.model.save_custom_fields(true)
            perform_update
          end

          it "updates the Note content" do
            expect(note.reload.content).to eq("Updated content")
          end

          it "creates an Update Activity" do
            expect(
               post.activity_pub_actor.activities.where(
                 object_id: post.activity_pub_object.id,
                 object_type: 'DiscourseActivityPubObject',
                 ap_type: 'Update'
              ).exists?
            ).to eq(true)
          end

          it "doesn't create multiple unpublished activities" do
            perform_update
            expect(
               post.activity_pub_actor.activities.where(
                 object_id: post.activity_pub_object.id,
                 object_type: 'DiscourseActivityPubObject',
                 ap_type: 'Update'
              ).size
            ).to eq(1)
          end

          it "creates multiple published activities" do
            perform_update

            attrs = {
              object_id: post.activity_pub_object.id,
              object_type: 'DiscourseActivityPubObject',
              ap_type: 'Update'
            }
            post.activity_pub_actor.activities
              .where(attrs)
              .update_all(published_at: Time.now)

            perform_update

            expect(
               post.activity_pub_actor.activities.where(attrs).size
            ).to eq(2)
          end
        end

        context "with replies" do
          before do
            reply.perform_activity_pub_activity(:update)
          end

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
        let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note, actor: category.activity_pub_actor) }

        before do
          SiteSetting.activity_pub_delivery_delay_minutes = 3
        end

        def perform_delete
          post.trash!
          post.perform_activity_pub_activity(:delete)
        end

        context "while in pre publication period" do
          it "does not create an object" do
            perform_delete
            expect(
              DiscourseActivityPubObject.exists?(model_id: post.id)
            ).to eq(false)
          end

          it "does not create an activity" do
            perform_delete
            expect(
               post.activity_pub_actor.activities.where(
                 ap_type: 'Delete'
              ).exists?
            ).to eq(false)
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
            expect(post.custom_fields['activity_pub_scheduled_at']).to eq(nil)
            expect(post.custom_fields['activity_pub_published_at']).to eq(nil)
            expect(post.custom_fields['activity_pub_deleted_at']).to eq(nil)
          end

          it "clears associated jobs" do
            follower1 = Fabricate(:discourse_activity_pub_actor_person)
            follow1 = Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: create.actor)
            follower2 = Fabricate(:discourse_activity_pub_actor_person)
            follow2 = Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: create.actor)
            job1_args = {
              object_id: create.id,
              object_type: 'DiscourseActivityPubActivity',
              from_actor_id: create.actor.id,
              to_actor_id: follower1.id
            }
            job2_args = {
              object_id: create.id,
              object_type: 'DiscourseActivityPubActivity',
              from_actor_id: create.actor.id,
              to_actor_id: follower2.id
            }
            Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job1_args).once
            Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job2_args).once
            perform_delete
          end
        end

        context "after publication" do
          before do
            note.model.custom_fields['activity_pub_published_at'] = Time.now
            note.model.save_custom_fields(true)
          end

          it "creates the right activity" do
            perform_delete
            expect(
              post.activity_pub_actor.activities.where(
                ap_type: 'Delete'
              ).exists?
            ).to eq(true)
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
            let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category.activity_pub_actor) }
            let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow2) { Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: category.activity_pub_actor) }

            it "enqueues delivery of activity to category's followers" do
              perform_delete
              activity = category.activity_pub_actor.activities.where(
                ap_type: 'Delete'
              ).first
              job1_args = {
                object_id: activity.id,
                object_type: 'DiscourseActivityPubActivity',
                from_actor_id: category.activity_pub_actor.id,
                to_actor_id: follower1.id
              }
              job2_args = {
                object_id: activity.id,
                object_type: 'DiscourseActivityPubActivity',
                from_actor_id: category.activity_pub_actor.id,
                to_actor_id: follower2.id
              }
              expect(
                job_enqueued?(job: :discourse_activity_pub_deliver, args: job1_args)
              ).to eq(true)
              expect(
                job_enqueued?(job: :discourse_activity_pub_deliver, args: job2_args)
              ).to eq(true)
            end
          end
        end

        context "with replies" do
          before do
            reply.perform_activity_pub_activity(:update)
          end

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
          category.custom_fields['activity_pub_post_object_type'] = 'Article'
          category.save_custom_fields(true)
        end

        context 'with create' do
          before do
            post.perform_activity_pub_activity(:create)
            post.reload
          end

          it "creates the right object" do
            expect(
              post.activity_pub_object.ap_type
            ).to eq('Article')
            expect(
              post.activity_pub_object.reply_to_id
            ).to eq(nil)
          end
        end

        context 'with update' do
          def perform_update
            post.custom_fields['activity_pub_content'] = "Updated content"
            post.perform_activity_pub_activity(:update)
          end

          context 'with an existing Note' do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

            it "does not change the object type" do
              perform_update
              expect(post.activity_pub_object.ap_type).to eq('Note')
            end
          end

          context 'with an existing Article' do
            let!(:article) { Fabricate(:discourse_activity_pub_object_article, model: post) }

            it "creates the right object" do
              perform_update
              expect(
                post.reload.activity_pub_object.ap_type
              ).to eq('Article')
            end
          end
        end

        context 'with delete' do
          def perform_delete
            post.trash!
            post.perform_activity_pub_activity(:delete)
          end

          context 'with an existing Note' do
            let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

            it "destroys the Note" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
            end
          end

          context 'with an existing Article' do
            let!(:article) { Fabricate(:discourse_activity_pub_object_article, model: post) }

            it "destroys the Article" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: article.id)).to eq(false)
            end
          end
        end
      end
    end

    context "with full_topic enabled on the category" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
        DiscourseActivityPub::UserHandler.update_or_create_actor(post.user)
        DiscourseActivityPub::UserHandler.update_or_create_actor(reply.user)
        post.topic.create_activity_pub_collection!
      end

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
            expect(
              post.activity_pub_object&.content
            ).to eq(post.activity_pub_content)
            expect(
              post.activity_pub_object&.reply_to_id
            ).to eq(nil)
          end

          it "creates the right activity" do
            perform_create
            expect(
               post.activity_pub_actor.activities.where(
                 object_id: post.activity_pub_object.id,
                 object_type: 'DiscourseActivityPubObject',
                 ap_type: 'Create'
              ).exists?
            ).to eq(true)
          end

          it "includes the object in the topic's object collection" do
            perform_create
            expect(
              post.activity_pub_object.ap_id
            ).to eq(topic.activity_pub_object.objects_collection.items.first.ap_id)
          end

          it "includes the activity in the topic's activity collection" do
            perform_create
            expect(
              post.activity_pub_actor.activities.first.ap_id
            ).to eq(topic.activity_pub_object.activities_collection.items.first.ap_id)
          end

          it "sends the topic collection as the topic actor for delayed delivery" do
            expect_delivery(
              actor: topic.activity_pub_actor,
              object: topic.activity_pub_object,
              delay: SiteSetting.activity_pub_delivery_delay_minutes.to_i
            )
            perform_create
          end
        end

        context "with delete" do
          let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
          let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

          def perform_delete
            post.trash!
            post.perform_activity_pub_activity(:delete)
          end

          context "while in pre publication period" do
            it "does not create an activity" do
              perform_delete
              expect(
                 post.activity_pub_actor.activities.where(
                   ap_type: 'Delete'
                ).exists?
              ).to eq(false)
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
              expect(note.model.custom_fields['activity_pub_scheduled_at']).to eq(nil)
              expect(note.model.custom_fields['activity_pub_published_at']).to eq(nil)
              expect(note.model.custom_fields['activity_pub_deleted_at']).to eq(nil)
            end

            it "clears associated jobs" do
              follower1 = Fabricate(:discourse_activity_pub_actor_person)
              follow1 = Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category.activity_pub_actor)
              follower2 = Fabricate(:discourse_activity_pub_actor_person)
              follow2 = Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: category.activity_pub_actor)
              job1_args = {
                object_id: topic.activity_pub_object.id,
                object_type: 'DiscourseActivityPubCollection',
                from_actor_id: topic.activity_pub_actor.id,
                to_actor_id: follower1.id
              }
              job2_args = {
                object_id: topic.activity_pub_object.id,
                object_type: 'DiscourseActivityPubCollection',
                from_actor_id: topic.activity_pub_actor.id,
                to_actor_id: follower2.id
              }
              Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job1_args).once
              Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job2_args).once
              perform_delete
            end

            it "does not send anything for delivery" do
              expect_no_delivery
              perform_delete
            end
          end

          context "after publication" do
            before do
              note.model.custom_fields['activity_pub_published_at'] = Time.now
              note.model.save_custom_fields(true)
            end

            it "creates the right activity" do
              perform_delete
              expect(
                 post.activity_pub_actor.activities.where(
                   ap_type: 'Delete'
                ).exists?
              ).to eq(true)
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

            it "sends the activity as the post actor for delivery without delay" do
              expect_delivery(
                actor: post.activity_pub_actor,
                object_type: "Delete"
              )
              perform_delete
            end
          end
        end

        context "with update" do
          let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
          let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

          def perform_update
            post.custom_fields['activity_pub_content'] = "Updated content"
            post.perform_activity_pub_activity(:update)
          end

          context "while not published" do
            it "updates the Note content" do
              perform_update
              expect(note.reload.content).to eq("Updated content")
            end

            it "does not create an Update Activity" do
              perform_update
              expect(
                 post.activity_pub_actor.activities.where(
                   ap_type: 'Update'
                ).exists?
              ).to eq(false)
            end

            it "does not send anything for delivery" do
              expect_no_delivery
              perform_update
            end
          end

          context "after publication" do
            before do
              note.model.custom_fields['activity_pub_published_at'] = Time.now
              note.model.save_custom_fields(true)
            end

            it "updates the Note content" do
              perform_update
              expect(note.reload.content).to eq("Updated content")
            end

            it "creates an Update Activity" do
              perform_update
              expect(
                 post.activity_pub_actor.activities.where(
                   object_id: post.activity_pub_object.id,
                   object_type: 'DiscourseActivityPubObject',
                   ap_type: 'Update'
                ).exists?
              ).to eq(true)
            end

            it "doesn't create multiple unpublished activities" do
              perform_update
              expect(
                 post.activity_pub_actor.activities.where(
                   object_id: post.activity_pub_object.id,
                   object_type: 'DiscourseActivityPubObject',
                   ap_type: 'Update'
                ).size
              ).to eq(1)
            end

            it "creates multiple published activities" do
              perform_update

              attrs = {
                object_id: post.activity_pub_object.id,
                object_type: 'DiscourseActivityPubObject',
                ap_type: 'Update'
              }
              post.activity_pub_actor.activities
                .where(attrs)
                .update_all(published_at: Time.now)

              perform_update

              expect(
                 post.activity_pub_actor.activities.where(attrs).size
              ).to eq(2)
            end

            it "sends the activity as the post actor for delivery without delay" do
              expect_delivery(
                actor: post.activity_pub_actor,
                object_type: "Update"
              )
              perform_update
            end
          end
        end
      end

      context "with replies" do
        let!(:post_note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

        context "with create" do
          def perform_create
            reply.perform_activity_pub_activity(:create)
            reply.reload
          end

          it "creates the right object" do
            perform_create
            expect(
              reply.activity_pub_object&.content
            ).to eq(reply.activity_pub_content)
            expect(
              reply.activity_pub_object&.reply_to_id
            ).to eq(post_note.ap_id)
            expect(
              reply.activity_pub_object&.collection_id
            ).to eq(topic.activity_pub_object.id)
          end

          it "creates the right activity" do
            perform_create
            expect(
               reply.activity_pub_actor.activities.where(
                 object_id: reply.activity_pub_object.id,
                 object_type: 'DiscourseActivityPubObject',
                 ap_type: 'Create'
              ).exists?
            ).to eq(true)
          end

          context "while not published" do
            it "does not send anything for delivery" do
              expect_no_delivery
              perform_create
            end
          end

          context "after topic publication" do
            before do
              post.custom_fields['activity_pub_published_at'] = Time.now
              post.save_custom_fields(true)
            end

            it "sends the activity as the topic actor for delivery without delay" do
              expect_delivery(
                actor: topic.activity_pub_actor,
                object_type: "Create"
              )
              perform_create
            end
          end
        end

        context "with update" do
          let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: reply) }
          let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

          def perform_update
            reply.custom_fields['activity_pub_content'] = "Updated content"
            reply.perform_activity_pub_activity(:update)
          end

          context "while not published" do
            it "updates the Note content" do
              perform_update
              expect(note.reload.content).to eq("Updated content")
            end

            it "does not create an Update Activity" do
              perform_update
              expect(
                 reply.activity_pub_actor.activities.where(
                   ap_type: 'Update'
                ).exists?
              ).to eq(false)
            end

            it "does not send anything for delivery" do
              expect_no_delivery
              perform_update
            end
          end

          context "after publication" do
            before do
              post.custom_fields['activity_pub_published_at'] = Time.now
              post.save_custom_fields(true)
              reply.custom_fields['activity_pub_published_at'] = Time.now
              reply.save_custom_fields(true)
            end

            it "updates the Note content" do
              perform_update
              expect(note.reload.content).to eq("Updated content")
            end

            it "creates an Update Activity" do
              perform_update
              expect(
                 reply.activity_pub_actor.activities.where(
                   object_id: reply.activity_pub_object.id,
                   object_type: 'DiscourseActivityPubObject',
                   ap_type: 'Update'
                ).exists?
              ).to eq(true)
            end

            it "doesn't create multiple unpublished activities" do
              perform_update
              expect(
                 reply.activity_pub_actor.activities.where(
                   object_id: reply.activity_pub_object.id,
                   object_type: 'DiscourseActivityPubObject',
                   ap_type: 'Update'
                ).size
              ).to eq(1)
            end

            it "creates multiple published activities" do
              perform_update

              attrs = {
                object_id: reply.activity_pub_object.id,
                object_type: 'DiscourseActivityPubObject',
                ap_type: 'Update'
              }
              reply.activity_pub_actor.activities
                .where(attrs)
                .update_all(published_at: Time.now)

              perform_update

              expect(
                reply.activity_pub_actor.activities.where(attrs).size
              ).to eq(2)
            end

            it "sends the activity as the post actor for delivery without delay" do
              expect_delivery(
                actor: reply.activity_pub_actor,
                object_type: "Update"
              )
              perform_update
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
              expect(
                DiscourseActivityPubObject.exists?(model_id: reply.id)
              ).to eq(false)
            end

            it "does not create an activity" do
              perform_delete
              expect(
                 reply.activity_pub_actor.activities.where(
                   ap_type: 'Delete'
                ).exists?
              ).to eq(false)
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
              expect(note.model.custom_fields['activity_pub_scheduled_at']).to eq(nil)
              expect(note.model.custom_fields['activity_pub_published_at']).to eq(nil)
              expect(note.model.custom_fields['activity_pub_deleted_at']).to eq(nil)
            end

            it "clears associated jobs" do
              follower1 = Fabricate(:discourse_activity_pub_actor_person)
              follow1 = Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: create.actor)
              follower2 = Fabricate(:discourse_activity_pub_actor_person)
              follow2 = Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: create.actor)
              job1_args = {
                object_id: create.id,
                object_type: 'DiscourseActivityPubActivity',
                from_actor_id: create.actor.id,
                to_actor_id: follower1.id
              }
              job2_args = {
                object_id: create.id,
                object_type: 'DiscourseActivityPubActivity',
                from_actor_id: create.actor.id,
                to_actor_id: follower2.id
              }
              Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job1_args).once
              Jobs.expects(:cancel_scheduled_job).with(:discourse_activity_pub_deliver, **job2_args).once
              perform_delete
            end

            it "does not send anything for delivery" do
              expect_no_delivery
              perform_delete
            end
          end

          context "after publication" do
            before do
              post.custom_fields['activity_pub_published_at'] = Time.now
              post.save_custom_fields(true)
              reply.custom_fields['activity_pub_published_at'] = Time.now
              reply.save_custom_fields(true)
            end

            it "creates the right activity" do
              perform_delete
              expect(
                 reply.activity_pub_actor.activities.where(
                   ap_type: 'Delete'
                ).exists?
              ).to eq(true)
            end

            it "does not destroy associated objects" do
              perform_delete
              expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
            end

            it "does not destroy associated activities" do
              perform_delete
              expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
            end

            it "sends the activity as the post actor for delivery without delay" do
              expect_delivery(
                actor: reply.activity_pub_actor,
                object_type: "Delete"
              )
              perform_delete
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
            expect(
              reply.activity_pub_object&.content
            ).to eq(reply.activity_pub_content)
            expect(
              reply.activity_pub_object&.reply_to_id
            ).to eq(post_note.ap_id)
          end
        end
      end
    end
  end
end
