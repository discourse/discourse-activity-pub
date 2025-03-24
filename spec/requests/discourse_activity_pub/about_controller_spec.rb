# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AboutController do
  let!(:tag) { Fabricate(:tag) }
  let!(:category1) { Fabricate(:category) }
  let!(:category2) { Fabricate(:category) }
  let!(:tag_actor_1) { Fabricate(:discourse_activity_pub_actor_group, model: tag, local: true) }
  let!(:category_actor_1) do
    Fabricate(:discourse_activity_pub_actor_group, model: category1, local: true)
  end
  let!(:category_actor_2) do
    Fabricate(:discourse_activity_pub_actor_group, model: category2, local: true)
  end
  let!(:category_actor_remote) { Fabricate(:discourse_activity_pub_actor_group, local: false) }
  let!(:person1) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:person2) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:person3) { Fabricate(:discourse_activity_pub_actor_person) }
  let!(:follow1) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: person1,
      followed: category_actor_2,
      created_at: (DateTime.now - 2),
    )
  end
  let!(:follow2) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: person2,
      followed: category_actor_2,
      created_at: (DateTime.now - 1),
    )
  end
  let!(:follow3) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: person3,
      followed: category_actor_1,
      created_at: DateTime.now,
    )
  end

  describe "#index" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        get "/ap/about.json"
        expect(response.status).to eq(404)
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      it "returns about json" do
        get "/ap/about.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["category_actors"].size).to eq(0)
      end

      context "with active actors" do
        it "returns active actors" do
          toggle_activity_pub(category1)
          toggle_activity_pub(category2)

          get "/ap/about.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["category_actors"].size).to eq(2)
          expect(response.parsed_body["category_actors"].map { |c| c["id"] }).to eq(
            [category_actor_2.id, category_actor_1.id],
          )
          expect(response.parsed_body["tag_actors"].size).to eq(0)

          toggle_activity_pub(tag)

          get "/ap/about.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["category_actors"].size).to eq(2)
          expect(response.parsed_body["tag_actors"].size).to eq(1)
        end
      end
    end
  end
end
