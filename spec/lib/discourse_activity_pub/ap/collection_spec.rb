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

  describe "#process" do
    let!(:collection_json) do
      build_collection_json(
        items: [
          build_activity_json(type: "Create"),
          build_activity_json(type: "Create"),
          build_activity_json(type: "Update"),
        ],
      )
    end

    it "processes processable items" do
      DiscourseActivityPub::AP::Activity::Create.any_instance.expects(:process).twice
      DiscourseActivityPub::AP::Activity::Update.any_instance.expects(:process).once
      perform_process(collection_json)
    end
  end

  describe "#resolve_and_store" do
    let!(:collection_json) { build_collection_json(type: "OrderedCollection") }

    it "stores the collection" do
      described_class.resolve_and_store(collection_json)
      expect(DiscourseActivityPubCollection.exists?(ap_id: collection_json[:id])).to eq(true)
    end

    context "when store fails" do
      let!(:ar_error) { "Failed to save collection" }

      before do
        collection_stub = DiscourseActivityPubCollection.new
        collection_stub.errors.add(:base, ar_error)
        DiscourseActivityPubCollection
          .any_instance
          .expects(:save!)
          .raises(ActiveRecord::RecordInvalid.new(collection_stub))
          .once
      end

      context "with verbose logging enabled" do
        before { setup_logging }
        after { teardown_logging }

        it "logs the right error" do
          described_class.resolve_and_store(collection_json)
          expect(@fake_logger.errors.first).to match(ar_error)
        end
      end
    end
  end
end
