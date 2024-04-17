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
      expect(actor.domain).to eq("external.com")
      expect(actor.ap_type).to eq(json["type"])
      expect(actor.inbox).to eq(json["inbox"])
      expect(actor.outbox).to eq(json["outbox"])
      expect(actor.username).to eq(json["preferredUsername"])
      expect(actor.name).to eq(json["name"])
    end

    it "updates an actor if optional attributes have changed" do
      perform

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.name).to eq("Angus McLeod")

      perform(name: "Bob McLeod")

      actor = DiscourseActivityPubActor.find_by(ap_id: json["id"])
      expect(actor.name).to eq("Bob McLeod")
    end

    it "creates a new actor if required attributes have changed" do
      perform

      original_id = json["id"]
      new_id = "https://external.com/u/bob"
      perform(id: new_id)

      expect(DiscourseActivityPubActor.exists?(ap_id: original_id)).to eq(true)
      expect(DiscourseActivityPubActor.exists?(ap_id: new_id)).to eq(true)
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
