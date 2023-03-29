# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::OutboxesController do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:activity1) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor, created_at: (DateTime.now - 1)) }
  let!(:activity2) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor, created_at: (DateTime.now - 2)) }
  let!(:activity3) { Fabricate(:discourse_activity_pub_activity_reject, actor: actor, created_at: DateTime.now) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ActorsController }

  describe "#index" do
    before do
      toggle_activity_pub(actor.model)
    end

    it "returns an ordered collection of the actors activities" do
      get_from_outbox(actor)
      expect(response.status).to eq(200)
      expect(response.parsed_body['total_items']).to eq(3)
      expect(response.parsed_body['ordered_items'][0]['id']).to eq(activity3.ap_id)
      expect(response.parsed_body['ordered_items'][1]['id']).to eq(activity1.ap_id)
      expect(response.parsed_body['ordered_items'][2]['id']).to eq(activity2.ap_id)
    end
  end
end
