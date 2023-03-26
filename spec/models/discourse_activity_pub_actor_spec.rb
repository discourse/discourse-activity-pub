# frozen_string_literal: true

RSpec.describe DiscourseActivityPubActor do
  let!(:category) { Fabricate(:category) }

  describe "#create" do
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

    context "with local domain and no preferred username" do
      context "with no preferred username" do
        it "raises an error" do
          expect{
            described_class.create!(
              model_id: category.id,
              model_type: category.class.name,
              uid: "foo",
              domain: Discourse.current_hostname,
              ap_type: DiscourseActivityPub::AP::Actor::Person.type
            )
          }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context "with a preferred username" do
        it "creates an actor " do
          actor = described_class.create!(
            model_id: category.id,
            model_type: category.class.name,
            uid: "foo",
            domain: Discourse.current_hostname,
            preferred_username: category.slug,
            ap_type: DiscourseActivityPub::AP::Actor::Group.type
          )
          expect(actor.errors.any?).to eq(false)
          expect(actor.persisted?).to eq(true)
        end
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
        enable_activity_pub(category)
      end

      it "ensures a valid actor exists" do
        described_class.ensure_for(category.reload)
        expect(category.activity_pub_actor.present?).to eq(true)
        expect(category.activity_pub_actor.uid).to eq(json_ld_id(category, 'Actor'))
        expect(category.activity_pub_actor.domain).to eq(Discourse.current_hostname)
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