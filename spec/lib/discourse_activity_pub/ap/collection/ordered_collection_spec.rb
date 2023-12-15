# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Collection::OrderedCollection do
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

  it { expect(described_class).to be < DiscourseActivityPub::AP::Collection }

  describe "#ordered_items" do
    it "returns items ordered in reverse chronological order" do
      expect(
        described_class.new(stored: actor.outbox_collection).ordered_items.map(&:id),
      ).to match_array([activity3.ap.id, activity1.ap.id, activity2.ap.id])
    end
  end
end
