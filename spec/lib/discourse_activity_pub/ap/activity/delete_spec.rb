# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Delete do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity::Compose }

  describe "#process" do
    before do
      toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
      topic.create_activity_pub_collection!
    end

    context "with valid Delete json" do
      let!(:object_json) { build_object_json }
      let!(:activity_json) do
        build_activity_json(
          object: object_json,
          type: "Delete",
          to: [category.activity_pub_actor.ap_id],
        )
      end
      let!(:note) do
        Fabricate(
          :discourse_activity_pub_object_note,
          ap_id: object_json[:id],
          local: false,
          model: post,
        )
      end

      before { perform_process(activity_json) }

      it "deletes the post" do
        expect(Post.exists?(post.id)).to be(false)
      end

      it "deletes the object" do
        expect(DiscourseActivityPubObject.exists?(note.id)).to be(false)
      end

      it "creates an activity" do
        expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
      end
    end
  end
end
