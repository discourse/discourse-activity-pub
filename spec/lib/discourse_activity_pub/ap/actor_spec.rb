# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Actor do
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
        expect(category.activity_pub_actor.uid).to eq(category.full_url)
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

  describe "#create_or_update_from_json" do
    let(:json) do
      {
        '@context': 'https://www.w3.org/ns/activitystreams',
        id: "https://external.com/u/angus",
        type: "Person",
        inbox: "https://external.com/u/angus/inbox",
        outbox: "https://external.com/u/angus/outbox",
        preferredUsername: "angus",
        name: "Angus McLeod"
      }.with_indifferent_access
    end

    let(:subject) do
      actor = described_class.new
      actor.json = json
      actor
    end

    before do
      subject.create_or_update_from_json
    end

    it "creates an actor" do
      actor = DiscourseActivityPubActor.find_by(uid: json['id'])
      expect(actor.present?).to eq(true)
      expect(actor.domain).to eq("external.com")
      expect(actor.ap_type).to eq(json["type"])
      expect(actor.inbox).to eq(json["inbox"])
      expect(actor.outbox).to eq(json["outbox"])
      expect(actor.preferred_username).to eq(json["preferredUsername"])
      expect(actor.name).to eq(json["name"])
    end

    it "updates an actor if optional attributes have changed" do
      json['name'] = "Bob McLeod"
      subject.json = json
      subject.create_or_update_from_json

      actor = DiscourseActivityPubActor.find_by(uid: json['id'])
      expect(actor.name).to eq("Bob McLeod")
    end

    it "creates a new actor if required attributes have changed" do
      original_id = json['id']
      json['id'] = "https://external.com/u/bob"
      subject.json = json
      subject.create_or_update_from_json

      expect(DiscourseActivityPubActor.exists?(uid: original_id)).to eq(true)
      expect(DiscourseActivityPubActor.exists?(uid: json['id'])).to eq(true)
    end
  end
end