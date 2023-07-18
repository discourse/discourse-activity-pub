# frozen_string_literal: true

RSpec.describe Post do
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:reply) { Fabricate(:post, topic_id: topic.id, post_number: 2) }

  it { is_expected.to have_one(:activity_pub_object) }

  describe "#activity_pub_enabled" do
    context "with activity pub plugin enabled" do
      context "with activity pub ready on category" do
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
    context "without activty pub enabled on the model" do
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

    context "with activity pub enabled on the model and a valid activity type" do
      before do
        DiscourseActivityPubActivity.any_instance.stubs(:deliver_composition).returns(true)
        toggle_activity_pub(category, callbacks: true)
        post.reload
      end

      context "with create" do
        before do
          post.perform_activity_pub_activity(:create)
        end

        it "creates the right object" do
          expect(
            post.reload.activity_pub_object.content
          ).to eq(post.activity_pub_content)
        end

        it "creates the right activity" do
          expect(
             post.activity_pub_actor.activities.where(
               object_id: post.activity_pub_object.id,
               object_type: 'DiscourseActivityPubObject',
               ap_type: 'Create'
            ).exists?
          ).to eq(true)
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
        let!(:create) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

        before do
          SiteSetting.activity_pub_delivery_delay_minutes = 3
        end

        def perform_delete
          post.delete
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
            expect(note.model.custom_fields['activity_pub_scheduled_at']).to eq(nil)
            expect(note.model.custom_fields['activity_pub_published_at']).to eq(nil)
            expect(note.model.custom_fields['activity_pub_deleted_at']).to eq(nil)
          end

          it "clears associated jobs" do
            DiscourseActivityPubActivity.any_instance.unstub(:deliver_composition)

            follower1 = Fabricate(:discourse_activity_pub_actor_person)
            follow1 = Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: create.actor)
            follower2 = Fabricate(:discourse_activity_pub_actor_person)
            follow2 = Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: create.actor)

            create.deliver_composition
            expect(Jobs::DiscourseActivityPubDeliver.jobs.size).to eq(2)

            job1_args = {
              activity_id: create.id,
              from_actor_id: create.actor.id,
              to_actor_id: follower1.id
            }
            job2_args = {
              activity_id: create.id,
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
            perform_delete
          end

          it "creates the right activity" do
            expect(
               post.activity_pub_actor.activities.where(
                 ap_type: 'Delete'
              ).exists?
            ).to eq(true)
          end

          it "does not destroy associated objects" do
            expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(true)
          end

          it "does not destroy associated activities" do
            expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(true)
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
          end

          it "creates the right object" do
            expect(
              post.reload.activity_pub_object.ap_type
            ).to eq('Article')
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
            post.delete
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
  end
end
