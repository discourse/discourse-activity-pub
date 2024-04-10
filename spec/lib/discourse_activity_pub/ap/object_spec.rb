# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Object do
  describe "#factory" do
    it "generates an AP object from json" do
      expect(described_class.factory(build_activity_json)).to be_a(
        DiscourseActivityPub::AP::Activity::Follow,
      )
    end
  end

  describe "#json" do
    context "when AP object has storage" do
      let(:follow_activity) { Fabricate(:discourse_activity_pub_activity_follow) }

      it "generates json from storage" do
        ap = DiscourseActivityPub::AP::Activity::Follow.new(stored: follow_activity)
        expect(ap.json["id"]).to eq(follow_activity.ap_id)
        expect(ap.json["actor"]["id"]).to eq(follow_activity.actor.ap_id)
        expect(ap.json["object"]["id"]).to eq(follow_activity.object.ap_id)
      end

      context "with a create object" do
        let!(:audience) { "https://forum.com/actor/1/followers" }
        let!(:note) { Fabricate(:discourse_activity_pub_object_note, audience: audience) }
        let!(:create_activity) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

        it "copies the activity addressing to the object" do
          ap = DiscourseActivityPub::AP::Activity::Create.new(stored: create_activity)
          expect(ap.json["object"]["to"]).to eq(create_activity.to)
          expect(ap.json["object"]["cc"]).to eq(create_activity.cc)
        end
      end
    end
  end

  describe "#resolve_and_store" do
    let!(:json) { build_object_json.with_indifferent_access }
    let!(:subject) do
      object = described_class.new
      object.json = json
      object
    end

    context "with an id that resolves" do
      before do
        stub_request(:get, json["id"]).to_return(
          body: json.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
          status: 200,
        )
      end

      context "with an object that can belong to remote" do
        it "returns the object" do
          note = DiscourseActivityPub::AP::Object.resolve_and_store(json)
          expect(note.type).to eq("Note")
        end
      end

      context "with an object that cannot belong to remote" do
        before do
          json["type"] = "Service"
          stub_request(:get, json["id"]).to_return(
            body: json.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
            status: 200,
          )
        end

        context "with verbose logging enabled" do
          before do
            SiteSetting.activity_pub_verbose_logging = true
            setup_logging
          end
          after { teardown_logging }

          it "logs the right warning" do
            DiscourseActivityPub::AP::Object.resolve_and_store(json["id"])
            expect(@fake_logger.warnings.first).to eq(
              "[Discourse Activity Pub] Failed to process #{json["id"]}: Object is not supported",
            )
          end
        end
      end
    end

    context "with an id that does not resolve" do
      before { stub_request(:get, json["id"]).to_return(status: 400) }

      context "with verbose logging enabled" do
        before do
          SiteSetting.activity_pub_verbose_logging = true
          setup_logging
        end
        after { teardown_logging }

        it "logs the right warning" do
          DiscourseActivityPub::AP::Object.resolve_and_store(json["id"])
          expect(@fake_logger.warnings.last).to eq(
            "[Discourse Activity Pub] Failed to process #{json["id"]}: Could not resolve object",
          )
        end
      end
    end
  end
end
