# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Update do
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

    context "with valid Update json" do
      let!(:object_json) { build_object_json }
      let!(:activity_json) { build_activity_json(object: object_json, type: "Update") }

      context "with an existing note" do
        let!(:note) do
          Fabricate(
            :discourse_activity_pub_object_note,
            ap_id: object_json[:id],
            local: false,
            model: post,
          )
        end

        before { perform_process(activity_json) }

        it "updates the post raw" do
          expect(post.reload.raw).to eq(object_json[:content])
        end

        it "creates an activity" do
          expect(DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id])).to be(true)
        end
      end
    end
  end
end
