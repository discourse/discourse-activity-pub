# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::OutboxesController do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:activity1) do
    Fabricate(:discourse_activity_pub_activity_accept, actor: actor, created_at: (DateTime.now - 1))
  end
  let!(:activity2) do
    Fabricate(:discourse_activity_pub_activity_accept, actor: actor, created_at: (DateTime.now - 2))
  end
  let!(:activity3) do
    Fabricate(:discourse_activity_pub_activity_reject, actor: actor, created_at: DateTime.now)
  end

  it { expect(described_class).to be < DiscourseActivityPub::AP::ActorsController }

  before { SiteSetting.activity_pub_require_signed_requests = false }

  describe "#index" do
    before { toggle_activity_pub(actor.model) }

    it "returns an ordered collection of the actors activities" do
      get_from_outbox(actor)
      expect(response.status).to eq(200)
      expect(response.parsed_body["totalItems"]).to eq(3)
      expect(response.parsed_body["orderedItems"][0]["id"]).to eq(activity3.ap_id)
      expect(response.parsed_body["orderedItems"][1]["id"]).to eq(activity1.ap_id)
      expect(response.parsed_body["orderedItems"][2]["id"]).to eq(activity2.ap_id)
    end
  end
end
