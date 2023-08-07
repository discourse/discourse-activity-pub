# frozen_string_literal: true

RSpec.describe DiscourseActivityPubObject do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) {
    PostCreator.create!(
      Discourse.system_user,
      raw: "Original content",
      topic_id: topic.id
    )
  }

  describe "#create" do
    context "with an invalid model and activity pub type" do
      it "raises an error" do
        expect{
          described_class.create!(
            local: true,
            model_id: topic.id,
            model_type: topic.class.name,
            ap_id: "foo",
            ap_type: DiscourseActivityPub::AP::Object::Note.type
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an object " do
        actor = described_class.create!(
          local: true,
          model_id: post.id,
          model_type: post.class.name,
          ap_id: "foo",
          ap_type: DiscourseActivityPub::AP::Object::Note.type
        )
        expect(actor.errors.any?).to eq(false)
        expect(actor.persisted?).to eq(true)
      end
    end
  end

  describe '#to' do
    context "with a note" do
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
      let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

      it "inherits the addressing of its first activity" do
        expect(note.to).to eq(activity.to)
      end
    end

    context "with an announced topic collection" do
      let!(:follower) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:poster) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic) }
      let!(:post1) { Fabricate(:post, topic: topic) }
      let!(:post2) { Fabricate(:post, topic: topic) }
      let!(:post3) { Fabricate(:post, topic: topic) }
      let!(:note1) { Fabricate(:discourse_activity_pub_object_note, model: post1, collection_id: collection.id) }
      let!(:note2) { Fabricate(:discourse_activity_pub_object_note, model: post2, collection_id: collection.id) }
      let!(:note3) { Fabricate(:discourse_activity_pub_object_note, model: post3, collection_id: collection.id) }
      let!(:activity1) { Fabricate(:discourse_activity_pub_activity_create, actor: poster, object: note1) }
      let!(:activity2) { Fabricate(:discourse_activity_pub_activity_create, actor: poster, object: note2) }
      let!(:activity3) { Fabricate(:discourse_activity_pub_activity_create, actor: poster, object: note3) }
      let!(:announce1) { Fabricate(:discourse_activity_pub_activity_announce, object: activity1, actor: group) }
      let!(:announce2) { Fabricate(:discourse_activity_pub_activity_announce, object: activity2, actor: group) }
      let!(:announce3) { Fabricate(:discourse_activity_pub_activity_announce, object: activity3, actor: group) }
      let!(:public_collection_id) { DiscourseActivityPub::JsonLd.public_collection_id }

      before do
        collection.context = :announcement
      end

      it "publicly addresses the collection" do
        expect(collection.to).to eq(public_collection_id)
      end

      it "publicly addresses all announce activities" do
        expect(collection.items.map(&:to)).to match_array(
          [public_collection_id, public_collection_id, public_collection_id]
        )
      end

      it "publicly addresses all announced activities" do
        expect(collection.items.map(&:object).flatten.map(&:to)).to match_array(
          [public_collection_id, public_collection_id, public_collection_id]
        )
      end

      it "publicly addresses all notes" do
        expect(collection.items.map{ |item| item.object.object }.flatten.map(&:to)).to match_array(
          [public_collection_id, public_collection_id, public_collection_id]
        )
      end
    end
  end
end