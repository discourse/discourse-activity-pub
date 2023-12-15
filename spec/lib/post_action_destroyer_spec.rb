# frozen_string_literal: true

RSpec.describe PostActionDestroyer do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user1) { Fabricate(:user) }
  let!(:user2) { Fabricate(:user) }
  let!(:user3) { Fabricate(:user) }
  let!(:actor1) { Fabricate(:discourse_activity_pub_actor_person, model: user1) }
  let!(:actor2) { Fabricate(:discourse_activity_pub_actor_person, model: user2) }
  let!(:actor3) { Fabricate(:discourse_activity_pub_actor_person, model: user3) }
  let!(:post) { Fabricate(:post, user: user1, topic: topic) }
  let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
  let!(:post_action1) do
    Fabricate(
      :post_action,
      user: user2,
      post: post,
      post_action_type_id: PostActionType.types[:like],
    )
  end
  let!(:post_action2) do
    Fabricate(
      :post_action,
      user: user3,
      post: post,
      post_action_type_id: PostActionType.types[:like],
    )
  end
  let!(:like1) { Fabricate(:discourse_activity_pub_activity_like, actor: actor2, object: note) }
  let!(:like2) { Fabricate(:discourse_activity_pub_activity_like, actor: actor3, object: note) }

  def perform_destroy_like(user, post)
    PostActionDestroyer.destroy(user, post, :like)
  end

  describe "destroy" do
    context "with a full_topic activity pub post" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: "full_topic")
        post.topic.create_activity_pub_collection!
      end

      context "with a user with an actor" do
        it "calls the undo like callback" do
          PostAction.any_instance.expects(:perform_activity_pub_activity).with(:undo, :like).once
          perform_destroy_like(user2, post)
        end
      end

      context "with a user without an actor" do
        before { actor3.destroy! }

        it "does nothing" do
          PostAction.any_instance.expects(:perform_activity_pub_activity).never
          perform_destroy_like(user3, post)
        end
      end

      context "with a remote note" do
        before do
          note.local = false
          note.save!
        end

        it "calls the like callback" do
          PostAction.any_instance.expects(:perform_activity_pub_activity).with(:undo, :like).once
          perform_destroy_like(user2, post)
        end
      end
    end

    context "with a first_post activity pub post" do
      before { toggle_activity_pub(category, callbacks: true, publication_type: "first_post") }

      it "does not call any callbacks" do
        PostAction.any_instance.expects(:perform_activity_pub_activity).never
        perform_destroy_like(user2, post)
      end
    end

    context "with an non activity pub post" do
      it "does not call any callbacks" do
        PostAction.any_instance.expects(:perform_activity_pub_activity).never
        perform_destroy_like(user2, post)
      end
    end
  end
end
