# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Actor do
  describe "#update_stored_from_json" do
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
      subject.update_stored_from_json
    end

    it "creates an actor" do
      actor = DiscourseActivityPubActor.find_by(ap_id: json['id'])
      expect(actor.present?).to eq(true)
      expect(actor.domain).to eq("external.com")
      expect(actor.ap_type).to eq(json["type"])
      expect(actor.inbox).to eq(json["inbox"])
      expect(actor.outbox).to eq(json["outbox"])
      expect(actor.username).to eq(json["preferredUsername"])
      expect(actor.name).to eq(json["name"])
    end

    it "updates an actor if optional attributes have changed" do
      json['name'] = "Bob McLeod"
      subject.json = json
      subject.update_stored_from_json

      actor = DiscourseActivityPubActor.find_by(ap_id: json['id'])
      expect(actor.name).to eq("Bob McLeod")
    end

    it "creates a new actor if required attributes have changed" do
      original_id = json['id']
      json['id'] = "https://external.com/u/bob"
      subject.json = json
      subject.update_stored_from_json

      expect(DiscourseActivityPubActor.exists?(ap_id: original_id)).to eq(true)
      expect(DiscourseActivityPubActor.exists?(ap_id: json['id'])).to eq(true)
    end
  end
end