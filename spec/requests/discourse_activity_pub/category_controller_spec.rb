# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::CategoryController do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person, domain: 'google.com', username: 'bob') }
  let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: actor, created_at: (DateTime.now - 2)) }
  let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person, domain: 'twitter.com', username: 'jenny') }
  let!(:follow2) { Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: actor, created_at: (DateTime.now - 1)) }
  let!(:follower3) { Fabricate(:discourse_activity_pub_actor_person, domain: 'netflix.com', username: 'xavier') }
  let!(:follow3) { Fabricate(:discourse_activity_pub_follow, follower: follower3, followed: actor, created_at: DateTime.now) }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.auth.error.#{key}")] }
  end

  describe "#followers" do
    before do
      toggle_activity_pub(actor.model)
    end

    it "returns the categories followers" do
      get "/ap/category/#{actor.model.id}/followers.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body['followers'].map{|f| f["url"] }).to eq(
        [follower3.ap_id, follower2.ap_id, follower1.ap_id]
      )
    end

    it "orders by ap domain" do
      get "/ap/category/#{actor.model.id}/followers.json?order=domain"
      expect(response.status).to eq(200)
      expect(response.parsed_body['followers'].map{|f| f["domain"] }).to eq(
        ["twitter.com", "netflix.com", "google.com"]
      )
    end

    it "orders by ap username" do
      get "/ap/category/#{actor.model.id}/followers.json?order=username"
      expect(response.status).to eq(200)
      expect(response.parsed_body['followers'].map{|f| f["username"] }).to eq(
        ["xavier", "jenny", "bob"]
      )
    end

    it "paginates" do
      get "/ap/category/#{actor.model.id}/followers.json?limit=2&page=1"
      expect(response.status).to eq(200)
      expect(response.parsed_body['followers'].map{|f| f["url"] }).to eq(
        [follower1.ap_id]
      )
    end
  end
end