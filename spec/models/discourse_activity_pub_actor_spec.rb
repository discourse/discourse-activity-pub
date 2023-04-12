# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActor do
  let!(:category) { Fabricate(:category) }

  describe "#create" do
    context "with an invalid model and activity pub type" do
      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: category.id,
            model_type: category.class.name,
            username: category.slug,
            ap_id: "foo",
            domain: "domain.com",
            ap_type: DiscourseActivityPub::AP::Actor::Person.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      before do
        @actor = described_class.create!(
          local: true,
          model_id: category.id,
          model_type: category.class.name,
          username: category.slug,
          ap_id: "foo",
          domain: "domain.com",
          ap_type: DiscourseActivityPub::AP::Actor::Group.type
        )
      end

      it "creates an actor" do
        expect(@actor.errors.any?).to eq(false)
        expect(@actor.persisted?).to eq(true)
      end

      it "sets inboxes and outboxes for the actor" do
        expect(@actor.inbox).to eq("#{@actor.ap_id}/inbox")
        expect(@actor.outbox).to eq("#{@actor.ap_id}/outbox")
      end
    end

    context "with no username" do
      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: category.id,
            model_type: category.class.name,
            ap_type: DiscourseActivityPub::AP::Actor::Person.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a username" do
      it "creates an actor " do
        actor = described_class.create!(
          local: true,
          model_id: category.id,
          model_type: category.class.name,
          ap_id: "foo",
          ap_type: DiscourseActivityPub::AP::Actor::Group.type,
          username: category.slug
        )
        expect(actor.errors.any?).to eq(false)
        expect(actor.persisted?).to eq(true)
      end
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
        toggle_activity_pub(category)
      end

      it "ensures a valid actor exists" do
        described_class.ensure_for(category.reload)
        expect(category.activity_pub_actor.present?).to eq(true)
        expect(category.activity_pub_actor.ap_type).to eq('Group')
      end

      it "publishes activity pub state" do
        message = MessageBus.track_publish("/activity-pub") do
          described_class.ensure_for(category.reload)
        end.first
        expect(message.data).to eq(
          { model: { id: category.id, type: "category", ready: true, enabled: true } }
        )
      end

      it "does not duplicate actors" do
        described_class.ensure_for(category.reload)
        described_class.ensure_for(category)
        expect(DiscourseActivityPubActor.where(model_id: category.id).size).to eq(1)
      end
    end
  end
end