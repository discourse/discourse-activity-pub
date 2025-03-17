# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AboutController do
  let!(:category) { Fabricate(:category) }
  let!(:tag) { Fabricate(:tag) }
  let!(:category_actor) do
    Fabricate(:discourse_activity_pub_actor_group, model: category, local: true)
  end
  let!(:tag_actor) { Fabricate(:discourse_activity_pub_actor_group, model: tag, local: true) }
  let!(:second_category_actor) { Fabricate(:discourse_activity_pub_actor_person, local: true) }
  let!(:remote_category_actor) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

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
        expect(response.parsed_body["category_actors"].size).to eq(0)
      end

      context "with active actors" do
        it "returns active actors" do
          toggle_activity_pub(category)

          get "/ap/local/about.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["category_actors"].size).to eq(1)
          expect(response.parsed_body["tag_actors"].size).to eq(0)

          toggle_activity_pub(tag)

          get "/ap/local/about.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["category_actors"].size).to eq(1)
          expect(response.parsed_body["tag_actors"].size).to eq(1)
        end
      end
    end
  end
end
