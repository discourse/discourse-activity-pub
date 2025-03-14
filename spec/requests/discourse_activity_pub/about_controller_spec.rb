# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AboutController do
  let!(:local_actor1) { Fabricate(:discourse_activity_pub_actor_group, local: true) }
  let!(:local_actor2) { Fabricate(:discourse_activity_pub_actor_group, local: true) }
  let!(:local_actor3) { Fabricate(:discourse_activity_pub_actor_person, local: true) }
  let!(:remote_actor1) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

  describe "#index" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        get "/ap/local/about.json"
        expect(response.status).to eq(404)
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      it "returns about json" do
        get "/ap/local/about.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].size).to eq(0)
      end

      context "with active actors" do
        before { toggle_activity_pub(local_actor1.model) }

        it "returns active actors" do
          get "/ap/local/about.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].size).to eq(1)
        end
      end
    end
  end
end
