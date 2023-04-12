# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Collection::OrderedCollection do
  let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:activity1) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor, created_at: (DateTime.now - 1)) }
  let!(:activity2) { Fabricate(:discourse_activity_pub_activity_accept, actor: actor, created_at: (DateTime.now - 2)) }
  let!(:activity3) { Fabricate(:discourse_activity_pub_activity_reject, actor: actor, created_at: DateTime.now) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Collection }

  describe "#ordered_items" do
    it "returns items ordered in reverse chronological order" do
      expect(described_class.new(stored: actor, collection_for: "outbox").ordered_items.map(&:id)).to match_array(
        [activity3.ap.id, activity1.ap.id, activity2.ap.id]
      )
    end
  end
end