# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::CategoryController do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:follower1) do
    Fabricate(
      :discourse_activity_pub_actor_person,
      domain: "google.com",
      username: "bob_ap",
      model: Fabricate(:user, username: "bob_local"),
    )
  end
  let!(:follow1) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: follower1,
      followed: actor,
      created_at: (DateTime.now - 2),
    )
  end
  let!(:follower2) do
    Fabricate(
      :discourse_activity_pub_actor_person,
      domain: "twitter.com",
      username: "jenny_ap",
      model: nil,
    )
  end
  let!(:follow2) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: follower2,
      followed: actor,
      created_at: (DateTime.now - 1),
    )
  end
  let!(:follower3) do
    Fabricate(
      :discourse_activity_pub_actor_person,
      domain: "netflix.com",
      username: "xavier_ap",
      model: Fabricate(:user, username: "xavier_local"),
    )
  end
  let!(:follow3) do
    Fabricate(
      :discourse_activity_pub_follow,
      follower: follower3,
      followed: actor,
      created_at: DateTime.now,
    )
  end

  describe "#followers" do
    context "with activity pub enabled" do
      before { toggle_activity_pub(actor.model) }

      it "returns the categories followers" do
        get "/ap/category/#{actor.model.id}/followers.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].map { |f| f["url"] }).to eq(
          [follower3.ap_id, follower2.ap_id, follower1.ap_id],
        )
      end

      it "returns followers without users" do
        get "/ap/category/#{actor.model.id}/followers.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].map { |f| f["username"] }).to include("jenny_ap")
      end

      it "orders by user" do
        get "/ap/category/#{actor.model.id}/followers.json?order=user"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].map { |f| f.dig("user", "username") }).to eq(
          ["xavier_local", "bob_local", nil],
        )
      end

      it "orders by actor" do
        get "/ap/category/#{actor.model.id}/followers.json?order=actor"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].map { |f| f["username"] }).to eq(
          %w[xavier_ap jenny_ap bob_ap],
        )
      end

      it "paginates" do
        get "/ap/category/#{actor.model.id}/followers.json?limit=2&page=1"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].map { |f| f["url"] }).to eq([follower1.ap_id])
      end
    end
  end
end
