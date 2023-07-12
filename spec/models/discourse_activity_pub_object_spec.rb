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
end