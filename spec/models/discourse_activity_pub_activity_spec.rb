# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActivity do
  let!(:category) { Fabricate(:category) }
  let!(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow) }

  describe "#create" do
    context "with an invalid object type" do
      it "raises an error" do
        expect{
          described_class.create!(
            actor: follow_activity.object,
            local: true,
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
            actor: follow_activity.object,
            local: true,
            ap_type: 'Maybe',
            object_id: follow_activity.id,
            object_type: follow_activity.class.name
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an activity" do
        accept = described_class.create!(
          actor: follow_activity.object,
          local: true,
          ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
          object_id: follow_activity.id,
          object_type: follow_activity.class.name
        )
        expect(accept.errors.any?).to eq(false)
        expect(accept.persisted?).to eq(true)
      end
    end
  end

  describe "#after_create" do
    before do
      toggle_activity_pub(category, with_actor: true)
    end

    context "when not composed type" do
      it "does not initiate delivery via ap" do
        DiscourseActivityPub::AP::Activity::Accept.any_instance.expects(:deliver).never

        described_class.create!(
          actor: follow_activity.object,
          local: true,
          ap_type: DiscourseActivityPub::AP::Activity::Accept.type,
          object_id: follow_activity.id,
          object_type: follow_activity.class.name
        )
      end
    end

    context "when composed type" do
      let!(:create_activity) { Fabricate(:discourse_activity_pub_activity_create) }

      it "initiates delivery via ap" do
        DiscourseActivityPub::AP::Activity::Create.any_instance.expects(:deliver).once

        described_class.create!(
          actor: category.activity_pub_actor,
          local: true,
          ap_type: DiscourseActivityPub::AP::Activity::Create.type,
          object_id: create_activity.object.id,
          object_type: create_activity.object.class.name
        )
      end
    end
  end
end