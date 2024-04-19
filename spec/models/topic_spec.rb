# frozen_string_literal: true

RSpec.describe Topic do
  before do
    freeze_time
    Jobs.run_immediately!
  end

  fab!(:user1) { Fabricate(:user, admin: true) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:category1) { Fabricate(:category, user: user1) }
  fab!(:category2) { Fabricate(:category, user: user1) }
  fab!(:topic1) { Fabricate(:topic, user: user1, category: category1, created_at: 4.hours.ago) }
  fab!(:topic2) { Fabricate(:topic, user: user2, category: category1, created_at: 2.days.ago) }
  fab!(:topic3) { Fabricate(:topic, user: user1, category: category2, created_at: 2.days.ago) }
  let!(:collection1) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic1) }
  let!(:collection2) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic2) }
  let!(:post1) { Fabricate(:post, topic: topic1) }
  let!(:post2) { Fabricate(:post, topic: topic1) }
  let!(:post3) { Fabricate(:post, topic: topic1) }
  let!(:note1) do
    Fabricate(:discourse_activity_pub_object_note, model: post1, collection_id: collection1.id)
  end
  let!(:note2) do
    Fabricate(:discourse_activity_pub_object_note, model: post2, collection_id: collection1.id)
  end
  let!(:note3) do
    Fabricate(:discourse_activity_pub_object_note, model: post3, collection_id: collection1.id)
  end
  let!(:activity1) { Fabricate(:discourse_activity_pub_activity_create, object: note1) }
  let!(:activity2) { Fabricate(:discourse_activity_pub_activity_create, object: note2) }
  let!(:activity3) { Fabricate(:discourse_activity_pub_activity_create, object: note3) }

  describe "move_posts" do
    before { toggle_activity_pub(category1, callbacks: true, publication_type: "full_topic") }

    context "with an ap full_topic topic to a new ap full_topic topic" do
      before do
        topic1.move_posts(
          user1,
          [post1.id, post3.id],
          title: "New topic in ap category",
          category_id: category1.id,
        )
        @new_topic = post3.reload.topic
        @first_post = @new_topic.first_post
      end

      it "moves the posts" do
        expect([topic1.id, topic2.id, topic3.id]).to_not include(@new_topic.id)
        expect(@first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic.id).to eq(topic1.id)
      end

      it "creates a collection for the new topic" do
        expect(@new_topic.activity_pub_object&.ap&.collection?).to eq(true)
      end

      it "does not create new objects or activities" do
        expect(DiscourseActivityPubObject.all.size).to eq(3)
        expect(DiscourseActivityPubActivity.all.size).to eq(3)
      end

      it "updates the note references" do
        expect(note1.reload.model_id).to eq(@first_post.id)
        expect(note1.collection_id).to eq(@new_topic.activity_pub_object.id)
        expect(note2.reload.collection_id).to eq(collection1.id)
      end
    end

    context "with an ap full_topic topic to an existing ap full_topic topic" do
      before do
        topic1.move_posts(user1, [post1.id, post3.id], destination_topic_id: topic2.id)
        @first_post = topic2.first_post
      end

      it "moves the posts" do
        expect(topic2.posts.size).to eq(2)
        expect(@first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic_id).to eq(topic1.id)
        expect(post3.reload.topic_id).to eq(topic2.id)
      end

      it "does not create new collections, objects or activities" do
        expect(DiscourseActivityPubCollection.all.size).to eq(2)
        expect(DiscourseActivityPubObject.all.size).to eq(3)
        expect(DiscourseActivityPubActivity.all.size).to eq(3)
      end

      it "updates the note references" do
        expect(note1.reload.model_id).to eq(@first_post.reload.id)
        expect(note1.collection_id).to eq(collection2.id)
        expect(note2.reload.collection_id).to eq(collection1.id)
      end
    end

    context "with an ap full_topic topic to a new non ap topic" do
      before do
        topic1.move_posts(
          user1,
          [post1.id, post3.id],
          title: "New topic in another category",
          category_id: category2.id,
        )
        @new_topic = post3.reload.topic
        @first_post = @new_topic.first_post
      end

      it "moves the posts" do
        expect(@new_topic.category_id).to eq(category2.id)
        expect(post2.reload.topic.category_id).to eq(category1.id)
        expect(post3.reload.topic.category_id).to eq(category2.id)
      end

      it "does not create new collections, objects or activities" do
        expect(DiscourseActivityPubCollection.all.size).to eq(2)
        expect(DiscourseActivityPubObject.all.size).to eq(3)
        expect(DiscourseActivityPubActivity.all.size).to eq(3)
      end

      it "updates the note references" do
        expect(note1.reload.model_id).to eq(@first_post.id)
        expect(note1.reload.collection_id).to eq(nil)
        expect(note2.reload.collection_id).to eq(collection1.id)
      end
    end

    context "with an ap full_topic topic to an existing non ap topic" do
      before do
        topic1.move_posts(
          user1,
          [post1.id, post3.id],
          destination_topic_id: topic3.id,
          category_id: category2.id,
        )
        @first_post = topic3.first_post
      end

      it "moves the posts" do
        expect(topic3.posts.size).to eq(2)
        expect(@first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic_id).to eq(topic1.id)
        expect(post3.reload.topic_id).to eq(topic3.id)
      end

      it "does not create new collections, objects or activities" do
        expect(DiscourseActivityPubCollection.all.size).to eq(2)
        expect(DiscourseActivityPubObject.all.size).to eq(3)
        expect(DiscourseActivityPubActivity.all.size).to eq(3)
      end

      it "updates the note references" do
        expect(note1.reload.model_id).to eq(@first_post.id)
        expect(note1.reload.collection_id).to eq(nil)
        expect(note2.reload.collection_id).to eq(collection1.id)
      end
    end
  end
end
