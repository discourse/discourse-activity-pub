# frozen_string_literal: true

RSpec.describe PostActionCreator do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user1) { Fabricate(:user) }
  let!(:user2) { Fabricate(:user) }
  let!(:user3) { Fabricate(:user) }
  let!(:actor1) { Fabricate(:discourse_activity_pub_actor_person, model: user1) }
  let!(:actor2) { Fabricate(:discourse_activity_pub_actor_person, model: user2) }
  let!(:post) { Fabricate(:post, user: user1, topic: topic) }
  let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }

  def perform_like(user, post)
    PostActionCreator.like(user, post)
  end

  describe "like" do
    context "with a full_topic activity pub post" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
        post.topic.create_activity_pub_collection!
      end

      context "with a user with an actor" do
        it "doesnt create a new actor" do
          perform_like(user2, post)
          expect(DiscourseActivityPubActor.where(ap_type: 'Person').size).to eq(2)
        end

        it "calls the like callback" do
          PostAction.any_instance.expects(:perform_activity_pub_activity).with(:like).once
          perform_like(user2, post)
        end
      end

      context "with a user without an actor" do
        it "creates a new actor" do
          perform_like(user3, post)
          expect(DiscourseActivityPubActor.exists?(model_id: user3.id)).to eq(true)
        end

        it "calls the like callback" do
          PostAction.any_instance.expects(:perform_activity_pub_activity).with(:like).once
          perform_like(user3, post)
        end
      end

      context "with a remote note" do
        before do
          note.local = false
          note.save!
        end

        it "calls the like callback" do
          PostAction.any_instance.expects(:perform_activity_pub_activity).with(:like).once
          perform_like(user2, post)
        end
      end
    end

    context "with a first_post activity pub post" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: 'first_post')
      end

      it "does not call any callbacks" do
        PostAction.any_instance.expects(:perform_activity_pub_activity).never
        perform_like(user2, post)
      end
    end

    context "with an non activity pub post" do
      it "does not call any callbacks" do
        PostAction.any_instance.expects(:perform_activity_pub_activity).never
        perform_like(user2, post)
      end
    end
  end
end