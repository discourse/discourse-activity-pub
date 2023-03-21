# frozen_string_literal: true

RSpec.describe DiscourseActivityPubObject do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }

  describe "#create" do
    context "with an invalid model and activity pub type" do
      it "raises an error" do
        expect{
          described_class.create!(
            model_id: topic.id,
            model_type: topic.class.name,
            uid: "foo",
            ap_type: DiscourseActivityPub::AP::Object::Note.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an object " do
        actor = described_class.create!(
          model_id: post.id,
          model_type: post.class.name,
          uid: "foo",
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
        expect(post.activity_pub_objects.present?).to eq(false)
      end
    end

    context "with an invalid activity type" do
      it "does nothing" do
        expect(described_class.handle_model_callback(post, :follow)).to eq(nil)
        expect(post.activity_pub_objects.present?).to eq(false)
      end
    end

    context "with activity pub enabled on the model and a valid activity" do
      before do
        category.activity_pub_enable!
        DiscourseActivityPubActivity.any_instance.expects(:deliver).once
      end

      context "with create" do
        before do
          described_class.handle_model_callback(post, :create)
        end

        it "creates the right object" do
          expect(
            post.activity_pub_objects.where(
              uid: post.activity_pub_id,
              ap_type: post.activity_pub_type,
              content: post.activity_pub_content
            ).exists?
          ).to eq(true)
        end

        it "creates the right activity" do
          expect(
             post.activity_pub_actor.activities.where(
               object_id: post.activity_pub_objects.first.id,
               object_type: 'DiscourseActivityPubObject',
               ap_type: 'Create'
            ).exists?
          ).to eq(true)
        end
      end

      context "with update" do
        before do
          post.raw = "Updated post"
          post.rebake!
          described_class.handle_model_callback(post, :update)
        end

        it "creates the right object" do
          expect(
            post.activity_pub_objects.where(
              uid: post.activity_pub_id,
              ap_type: post.activity_pub_type,
              content: "Updated post"
            ).exists?
          ).to eq(true)
        end

        it "creates the right activity" do
          expect(
             post.activity_pub_actor.activities.where(
               object_id: post.activity_pub_objects.first.id,
               object_type: 'DiscourseActivityPubObject',
               ap_type: 'Update'
            ).exists?
          ).to eq(true)
        end
      end

      context "with delete" do
        before do
          post.delete
          described_class.handle_model_callback(post, :delete)
        end

        it "creates the right object" do
          expect(
            post.activity_pub_objects.where(
              uid: post.activity_pub_id,
              ap_type: post.activity_pub_type,
              content: nil
            ).exists?
          ).to eq(true)
        end

        it "creates the right activity" do
          expect(
             post.activity_pub_actor.activities.where(
               object_id: post.activity_pub_objects.first.id,
               object_type: 'DiscourseActivityPubObject',
               ap_type: 'Delete'
            ).exists?
          ).to eq(true)
        end
      end
    end
  end
end