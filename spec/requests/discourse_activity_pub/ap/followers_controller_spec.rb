# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::FollowersController do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:follower1) do
    Fabricate(:discourse_activity_pub_actor_person, created_at: (DateTime.now - 1))
  end
  let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: actor) }
  let!(:follower2) do
    Fabricate(:discourse_activity_pub_actor_person, created_at: (DateTime.now - 2))
  end
  let!(:follow2) { Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: actor) }
  let!(:follower3) { Fabricate(:discourse_activity_pub_actor_person, created_at: DateTime.now) }
  let!(:follow3) { Fabricate(:discourse_activity_pub_follow, follower: follower3, followed: actor) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ActorsController }

  before { SiteSetting.activity_pub_require_signed_requests = false }

  describe "#index" do
    before { toggle_activity_pub(actor.model) }

    it "returns an ordered collection of the actors followers" do
      get_followers(actor)
      expect(response.status).to eq(200)
      expect(parsed_body["totalItems"]).to eq(3)
      expect(parsed_body["orderedItems"][0]["id"]).to eq(follower3.ap_id)
      expect(parsed_body["orderedItems"][1]["id"]).to eq(follower1.ap_id)
      expect(parsed_body["orderedItems"][2]["id"]).to eq(follower2.ap_id)
    end
  end
end
