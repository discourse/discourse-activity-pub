# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Collection do
  let!(:category) { Fabricate(:category) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:activity1) { Fabricate(:discourse_activity_pub_activity_accept, actor: group) }
  let!(:activity2) { Fabricate(:discourse_activity_pub_activity_accept, actor: group) }
  let!(:activity3) { Fabricate(:discourse_activity_pub_activity_reject, actor: group) }

  describe "#items" do
    it "returns activities" do
      expect(described_class.new(stored: group.outbox_collection).items.map(&:id)).to match_array(
        [activity1.ap.id, activity2.ap.id, activity3.ap.id],
      )
    end

    context "with an topic collection" do
      let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:topic) { Fabricate(:topic, category: category) }
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }
      let!(:post1) { Fabricate(:post, topic: topic) }
      let!(:post2) { Fabricate(:post, topic: topic) }
      let!(:post3) { Fabricate(:post, topic: topic) }
      let!(:note1) do
        Fabricate(:discourse_activity_pub_object_note, model: post1, collection_id: collection.id)
      end
      let!(:note2) do
        Fabricate(:discourse_activity_pub_object_note, model: post2, collection_id: collection.id)
      end
      let!(:note3) do
        Fabricate(:discourse_activity_pub_object_note, model: post3, collection_id: collection.id)
      end
      let!(:activity1) do
        Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note1)
      end
      let!(:activity2) do
        Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note2)
      end
      let!(:activity3) do
        Fabricate(:discourse_activity_pub_activity_create, actor: person, object: note3)
      end
      let!(:announce1) do
        Fabricate(:discourse_activity_pub_activity_announce, object: activity1, actor: group)
      end
      let!(:announce2) do
        Fabricate(:discourse_activity_pub_activity_announce, object: activity2, actor: group)
      end
      let!(:announce3) do
        Fabricate(:discourse_activity_pub_activity_announce, object: activity3, actor: group)
      end

      it "returns announced post activities" do
        expect(
          described_class.new(stored: collection.announcements_collection).items.map(&:id),
        ).to match_array([announce1.ap.id, announce2.ap.id, announce3.ap.id])
      end
    end
  end
end
