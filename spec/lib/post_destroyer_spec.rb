# frozen_string_literal: true

RSpec.describe PostDestroyer do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:user) { Fabricate(:user) }
  let!(:post1) { Fabricate(:post, user: user, topic: topic) }
  let!(:post2) { Fabricate(:post, user: user) }
  let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post1) }
  let!(:activity) do
    Fabricate(:discourse_activity_pub_activity_create, object: note, published_at: Time.now)
  end

  before { toggle_activity_pub(category) }

  def perform_destroy(post)
    PostDestroyer.new(user, post).destroy
  end

  def perform_recover(post)
    PostDestroyer.new(user, post).recover
  end

  describe "destroy" do
    context "with an activity pub post" do
      context "with a local note" do
        it "calls the delete callback" do
          post1.expects(:perform_activity_pub_activity).with(:delete).once
          perform_destroy(post1)
        end
      end

      describe "with a remote note" do
        before do
          note.local = false
          note.save!
        end

        it "does not call the delete callback" do
          post1.expects(:perform_activity_pub_activity).with(:delete).never
          perform_destroy(post1)
        end
      end
    end

    context "with an non activity pub post" do
      it "does not call any callbacks" do
        post2.expects(:perform_activity_pub_activity).never
        perform_destroy(post2)
      end
    end
  end

  describe "recover" do
    context "with an activity pub post" do
      context "with a local note" do
        it "calls the create callback" do
          post1.expects(:perform_activity_pub_activity).with(:create).once
          perform_recover(post1)
        end
      end

      describe "with a remote note" do
        before do
          note.local = false
          note.save!
        end

        it "does not call the create callback" do
          post1.expects(:perform_activity_pub_activity).with(:create).never
          perform_recover(post1)
        end
      end
    end

    context "with an non activity pub post" do
      it "does not call any callbacks" do
        post2.expects(:perform_activity_pub_activity).never
        perform_recover(post2)
      end
    end
  end
end
