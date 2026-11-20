# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Actor do
  let!(:json) { build_actor_json.with_indifferent_access }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Object }

  describe "#resolve_and_store" do
    def perform(extra_json = {})
      DiscourseActivityPub::AP::Actor.resolve_and_store(json.merge(extra_json))
    end

    it "creates an actor" do
      perform

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.present?).to eq(true)
      expect(actor.domain).to eq("remote.com")
      expect(actor.ap_type).to eq(json["type"])
      expect(actor.inbox).to eq(json["inbox"])
      expect(actor.outbox).to eq(json["outbox"])
      expect(actor.username).to eq(json["preferredUsername"])
      expect(actor.name).to eq(json["name"])
    end

    it "updates name if name has changed" do
      perform

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.name).to eq("Angus McLeod")

      perform(name: "Bob McLeod")

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.name).to eq("Bob McLeod")
    end

    it "updates username if preferredUsername has changed" do
      perform

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.username).to eq("angus")

      perform(preferredUsername: "bob")

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.username).to eq("bob")
    end

    it "creates a new actor if id has changed" do
      perform

      original_id = json["id"]
      new_id = "https://remote.com/u/bob"
      perform(id: new_id)

      expect(DiscourseActivityPubActor.exists?(ap_id: original_id)).to eq(true)
      expect(DiscourseActivityPubActor.exists?(ap_id: new_id)).to eq(true)
    end

    context "with a local actor" do
      let!(:user) { Fabricate(:user) }
      let!(:local_actor) do
        Fabricate(:discourse_activity_pub_actor_person, model: user, local: true)
      end

      it "does not update the local actor" do
        local_json = local_actor.ap.json.merge(name: "Attacker name", preferredUsername: "attacker")

        DiscourseActivityPub::AP::Actor.resolve_and_store(local_json)

        local_actor.reload
        expect(local_actor.name).not_to eq("Attacker name")
        expect(local_actor.username).not_to eq("attacker")
      end
    end

    context "with a linked remote actor" do
      let!(:user) { Fabricate(:user) }
      let!(:linked_actor) { Fabricate(:discourse_activity_pub_actor_person, local: false) }
      let!(:authorization) do
        Fabricate(:discourse_activity_pub_authorization, user: user, actor: linked_actor)
      end
      let!(:attacker_keypair) { OpenSSL::PKey::RSA.new(2048) }
      let!(:attacker_json) do
        linked_actor.ap.json.merge(
          name: "Attacker name",
          preferredUsername: "attacker",
          publicKey: {
            id: signature_key_id(linked_actor),
            owner: linked_actor.ap_id,
            publicKeyPem: attacker_keypair.public_key.to_pem,
          },
        )
      end

      it "does not update the linked actor from an embedded actor document" do
        DiscourseActivityPub::AP::Actor.resolve_and_store(attacker_json)

        linked_actor.reload
        expect(linked_actor.name).not_to eq("Attacker name")
        expect(linked_actor.username).not_to eq("attacker")
        expect(linked_actor.public_key).to eq(nil)
      end

      it "updates the linked actor from its own actor document" do
        stub_object_request(linked_actor, body: attacker_json.to_json)

        DiscourseActivityPub::AP::Actor.resolve_and_store(linked_actor.ap_id)

        expect(linked_actor.reload.name).to eq("Attacker name")
      end

      it "does not update the linked actor from a document served from another id" do
        other_id = "https://remote.com/u/attacker/#{SecureRandom.hex(8)}"
        stub_request(:get, other_id).to_return(
          body: attacker_json.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
          status: 200,
        )

        DiscourseActivityPub::AP::Actor.resolve_and_store(other_id)

        linked_actor.reload
        expect(linked_actor.name).not_to eq("Attacker name")
        expect(linked_actor.public_key).to eq(nil)
      end
    end

    context "with verbose logging enabled" do
      before { setup_logging }
      after { teardown_logging }

      it "logs a detailed error if validations fail" do
        DiscourseActivityPubActor.stubs(:find_by).returns(nil)
        stored = Fabricate(:discourse_activity_pub_actor_person)
        perform(stored.ap.json)
        expect(@fake_logger.errors.first).to include(
          "[Discourse Activity Pub] Ap has already been taken",
        )
      end

      it "prevents concurrent updates" do
        threads = 5.times.map { Thread.new { perform } }
        threads.map(&:join)
        expect(@fake_logger.errors.empty?).to eq(true)
      end
    end
  end
end
