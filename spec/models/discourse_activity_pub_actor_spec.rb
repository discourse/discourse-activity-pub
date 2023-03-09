# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActor do
  let!(:category) { Fabricate(:category) }

  context "with an invalid model and activity pub type" do
    it "raises an error" do
      expect{
        described_class.create!(
          model_id: category.id,
          model_type: category.class.name,
          uid: "foo",
          domain: "domain.com",
          ap_type: DiscourseActivityPub::AP::Actor::Person.type
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "with a valid model and activity pub type" do
    it "creates an actor " do
      actor = described_class.create!(
        model_id: category.id,
        model_type: category.class.name,
        uid: "foo",
        domain: "domain.com",
        ap_type: DiscourseActivityPub::AP::Actor::Group.type
      )
      expect(actor.errors.any?).to eq(false)
      expect(actor.persisted?).to eq(true)
    end
  end
end