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

  describe "#ensure_for" do
    let(:category) { Fabricate(:category) }

    context "without activty pub enabled on the object" do
      it "does not create an actor" do
        described_class.ensure_for(category)
        expect(category.activity_pub_actor.present?).to eq(false)
      end
    end

    context "with activity pub enabled on the object" do
      before do
        category.custom_fields['activity_pub_enabled'] = true
        category.save!
      end

      it "ensures a valid actor exists" do
        described_class.ensure_for(category)
        expect(category.activity_pub_actor.present?).to eq(true)
        expect(category.activity_pub_actor.uid).to eq(category.activity_pub_id)
        expect(category.activity_pub_actor.domain).to eq(Discourse.current_hostname)
        expect(category.activity_pub_actor.ap_type).to eq(category.activity_pub_type)
      end

      it "does not duplicate actors" do
        described_class.ensure_for(category)
        described_class.ensure_for(category)
        expect(DiscourseActivityPubActor.where(model_id: category.id).size).to eq(1)
      end
    end
  end
end