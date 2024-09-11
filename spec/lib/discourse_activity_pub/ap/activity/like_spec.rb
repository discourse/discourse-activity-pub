# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::Activity::Like do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::Activity }

  describe "#process" do
    before do
      toggle_activity_pub(category, publication_type: "full_topic")
      topic.create_activity_pub_collection!
    end

    context "with a new actor" do
      let!(:person) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:object_id) { "https://angus.eu.ngrok.io/ap/object/a85b4c2fde8128481178921f522df3af" }
      let!(:activity_json) { build_activity_json(object: object_id, type: "Like", actor: person) }

      context "with a remote note" do
        let!(:note) do
          Fabricate(
            :discourse_activity_pub_object_note,
            ap_id: object_id,
            local: false,
            model: post,
          )
        end

        before do
          stub_object_request(note)
          stub_object_request(note.attributed_to)
          perform_process(activity_json)
          @user =
            User.joins(:activity_pub_actor).where(activity_pub_actor: { ap_id: person.ap_id }).first
        end

        it "creates a user" do
          expect(@user.present?).to eq(true)
        end

        it "likes the post" do
          expect(
            PostAction.exists?(
              post_id: post.id,
              user_id: @user.id,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            ),
          ).to be(true)
        end

        it "creates an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id], ap_type: "Like"),
          ).to be(true)
        end

        it "adds the like to the post note's likes collection" do
          expect(note.likes_collection.items.first.ap_id).to eq(activity_json[:id])
        end
      end

      context "with a local note" do
        let!(:note) do
          Fabricate(:discourse_activity_pub_object_note, ap_id: object_id, local: true, model: post)
        end

        before do
          stub_object_request(note)
          stub_object_request(note.attributed_to)
          perform_process(activity_json)
          @user =
            User.joins(:activity_pub_actor).where(activity_pub_actor: { ap_id: person.ap_id }).first
        end

        it "creates a user" do
          expect(@user.present?).to eq(true)
        end

        it "likes the post" do
          expect(
            PostAction.exists?(
              post_id: post.id,
              user_id: @user.id,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            ),
          ).to be(true)
        end

        it "creates an activity" do
          expect(
            DiscourseActivityPubActivity.exists?(ap_id: activity_json[:id], ap_type: "Like"),
          ).to be(true)
        end

        it "adds the like to the post note's likes collection" do
          expect(note.likes_collection.items.first.ap_id).to eq(activity_json[:id])
        end
      end
    end
  end
end
