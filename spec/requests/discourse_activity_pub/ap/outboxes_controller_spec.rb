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
      expect(parsed_body["totalItems"]).to eq(3)
      expect(parsed_body["orderedItems"][0]["id"]).to eq(activity3.ap_id)
      expect(parsed_body["orderedItems"][1]["id"]).to eq(activity1.ap_id)
      expect(parsed_body["orderedItems"][2]["id"]).to eq(activity2.ap_id)
    end

    it "omits activities whose base object is no longer publishable" do
      tag = Fabricate(:tag)
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category, tags: [tag], title: "Restricted ActivityPub Topic")
      Fabricate(:post, topic: topic, post_number: 1)
      Fabricate(:post, topic: topic, post_number: 2)

      toggle_activity_pub(tag, publication_type: "full_topic")
      DiscourseActivityPub::Bulk::Publish.perform(topic_id: topic.id)
      category.update!(read_restricted: true)

      get_from_outbox(tag.activity_pub_actor.reload)

      expect(response.status).to eq(200)
      expect(parsed_body["totalItems"]).to eq(0)
      expect(response.body).not_to include(topic.title)
    end
  end
end
