# frozen_string_literal: true

RSpec.describe DiscourseActivityPubObject do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) do
    PostCreator.create!(Discourse.system_user, raw: "Original content", topic_id: topic.id)
  end

  describe "#create" do
    context "with an invalid model and activity pub type" do
      it "raises an error" do
        expect {
          described_class.create!(
            local: true,
            model_id: topic.id,
            model_type: topic.class.name,
            ap_id: "foo",
            ap_type: DiscourseActivityPub::AP::Object::Note.type,
          )
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with a valid model and activity pub type" do
      it "creates an object " do
        actor =
          described_class.create!(
            local: true,
            model_id: post.id,
            model_type: post.class.name,
            ap_id: "foo",
            ap_type: DiscourseActivityPub::AP::Object::Note.type,
          )
        expect(actor.errors.any?).to eq(false)
        expect(actor.persisted?).to eq(true)
      end
    end
  end

  describe "#audience" do
    context "with a note" do
      let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
      let!(:activity) { Fabricate(:discourse_activity_pub_activity_create, object: note) }

      it "inherits the addressing of its first activity" do
        expect(note.audience).to eq(activity.audience)
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
        Fabricate(:discourse_activity_pub_activity_create, actor: poster, object: note1)
      end
      let!(:activity2) do
        Fabricate(:discourse_activity_pub_activity_create, actor: poster, object: note2)
      end
      let!(:activity3) do
        Fabricate(:discourse_activity_pub_activity_create, actor: poster, object: note3)
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
      let!(:public_collection_id) { DiscourseActivityPub::JsonLd.public_collection_id }

      before { collection.context = :announcement }

      it "sets the collection audience" do
        expect(collection.audience).to eq(group.ap_id)
      end

      it "sets announce activities' audience" do
        collection.items.each { |item| expect(item.audience).to eq(group.ap_id) }
      end

      it "sets announced activities' audience" do
        collection.items.each { |item| expect(item.object.audience).to eq(group.ap_id) }
      end

      it "sets announced activities' notes' audience" do
        collection.items.each { |item| expect(item.object.object.audience).to eq(group.ap_id) }
      end
    end
  end
end
