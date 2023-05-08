# frozen_string_literal: true

RSpec.describe DiscourseActivityPubObject do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) {
    PostCreator.create!(
      Discourse.system_user,
      raw: "Original content",
      topic_id: topic.id
    )
  }
  let!(:reply) { Fabricate(:post, topic_id: topic.id, post_number: 2) }

  describe "#create" do
    context "with an invalid model and activity pub type" do
      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: topic.id,
            model_type: topic.class.name,
            ap_id: "foo",
            ap_type: DiscourseActivityPub::AP::Object::Note.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an object " do
        actor = described_class.create!(
          local: true,
          model_id: post.id,
          model_type: post.class.name,
          ap_id: "foo",
          ap_type: DiscourseActivityPub::AP::Object::Note.type
        )
        expect(actor.errors.any?).to eq(false)
        expect(actor.persisted?).to eq(true)
      end
    end
  end

  describe "#handle_model_callback" do
    context "without activty pub enabled on the model" do
      it "does nothing" do
        expect(described_class.handle_model_callback(post, :create)).to eq(nil)
        expect(post.reload.activity_pub_object.present?).to eq(false)
      end
    end

    context "with an invalid activity type" do
      it "does nothing" do
        expect(described_class.handle_model_callback(post, :follow)).to eq(nil)
        expect(post.reload.activity_pub_object.present?).to eq(false)
      end
    end

    context "with activity pub enabled on the model and a valid activity" do
      before do
        DiscourseActivityPubActivity.any_instance.stubs(:deliver_composition).returns(true)
        toggle_activity_pub(category, callbacks: true)
        post.reload
      end

      context "with create" do
        before do
          described_class.handle_model_callback(post, :create)
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
            described_class.handle_model_callback(reply, :create)
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
          described_class.handle_model_callback(post, :update)
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
          end

          it "does not update the Note content" do
            expect(note.reload.content).to eq("Original content")
          end

          it "does not create an Update Activity" do
            expect(
               post.activity_pub_actor.activities.where(
                 ap_type: 'Update'
              ).exists?
            ).to eq(false)
          end
        end

        context "with replies" do
          before do
            described_class.handle_model_callback(reply, :update)
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
          described_class.handle_model_callback(post, :delete)
        end

        context "while in pre publication period" do
          before do
            perform_delete
          end

          it "does not create an object" do
            expect(
              post.activity_pub_object.present?
            ).to eq(false)
          end

          it "does not create an activity" do
            expect(
               post.activity_pub_actor.activities.where(
                 ap_type: 'Delete'
              ).exists?
            ).to eq(false)
          end

          it "destroys associated objects" do
            expect(DiscourseActivityPubObject.exists?(id: note.id)).to eq(false)
          end

          it "destroys associated activities" do
            expect(DiscourseActivityPubActivity.exists?(id: create.id)).to eq(false)
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
            described_class.handle_model_callback(reply, :update)
          end

          it "does nothing" do
            expect(reply.activity_pub_enabled).to eq(false)
            expect(reply.activity_pub_content).to eq(nil)
            expect(reply.activity_pub_object).to eq(nil)
            expect(reply.activity_pub_actor).to eq(nil)
          end
        end
      end
    end
  end
end