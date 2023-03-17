# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActivity do
  let!(:category) { Fabricate(:category) }
  let!(:follow) { Fabricate(:discourse_activity_pub_activity_follow) }

  context "with an invalid object type" do
    it "raises an error" do
      expect{
        described_class.create!(
          actor: follow.object,
          ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
          object_id: category.id,
          object_type: category.class.name
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "with an invalid activity pub type" do
    it "raises an error" do
      expect{
        described_class.create!(
          actor: follow.object,
          ap_type: 'Maybe',
          object_id: follow.id,
          object_type: follow.class.name
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "with a valid model and activity pub type" do
    it "creates an activity " do
      accept = described_class.create!(
        actor: follow.object,
        ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
        object_id: follow.id,
        object_type: follow.class.name
      )
      expect(accept.errors.any?).to eq(false)
      expect(accept.persisted?).to eq(true)
    end
  end
end