# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Collection do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:activity1) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor) }
  let!(:activity2) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor) }
  let!(:activity3) { Fabricate(:discourse_activity_pub_activity_reject, actor: actor) }

  describe "#items" do
    it "returns stored activities as AP objects" do
      expect(described_class.new(stored: actor, collection_for: "outbox").items.map(&:id)).to match_array(
        [activity1.ap.id, activity2.ap.id, activity3.ap.id]
      )
    end
  end
end