# frozen_string_literal: true

RSpec.describe Topic do
  before do
    freeze_time
    Jobs.run_immediately!
  end

  fab!(:user1) { Fabricate(:user, admin: true) }
  fab!(:user2, :user)
  fab!(:category1) { Fabricate(:category, user: user1) }
  fab!(:category2) { Fabricate(:category, user: user1) }
  fab!(:topic1) { Fabricate(:topic, user: user1, category: category1, created_at: 4.hours.ago) }
  fab!(:topic2) { Fabricate(:topic, user: user2, category: category1, created_at: 2.days.ago) }
  fab!(:topic3) { Fabricate(:topic, user: user1, category: category2, created_at: 2.days.ago) }
  let!(:post1) { Fabricate(:post, topic: topic1) }
  let!(:post2) { Fabricate(:post, topic: topic1) }
  let!(:post3) { Fabricate(:post, topic: topic1) }

  describe "#activity_pub_enabled" do
    context "with activity pub plugin enabled" do
      context "with a private message" do
        let!(:topic) { Fabricate(:private_message_topic) }

        it { expect(topic.activity_pub_enabled).to eq(false) }
      end
    end
  end

  describe "move_posts", :aggregate_failures do
    context "with posts in an ap category" do
      let!(:note1) { Fabricate(:discourse_activity_pub_object_note, model: post1) }
      let!(:activity1) { Fabricate(:discourse_activity_pub_activity_create, object: note1) }

      context "with full_topic enabled" do
        let!(:collection1) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic1) }
        let!(:collection2) { Fabricate(:discourse_activity_pub_ordered_collection, model: topic2) }
        let!(:note2) do
          Fabricate(
            :discourse_activity_pub_object_note,
            model: post2,
            collection_id: collection1.id,
          )
        end
        let!(:note3) do
          Fabricate(
            :discourse_activity_pub_object_note,
            model: post3,
            collection_id: collection1.id,
          )
        end
        let!(:activity2) { Fabricate(:discourse_activity_pub_activity_create, object: note2) }
        let!(:activity3) { Fabricate(:discourse_activity_pub_activity_create, object: note3) }

        before do
          toggle_activity_pub(category1, publication_type: "full_topic")
          note1.update!(collection_id: collection1.id)
        end

        it "moves the posts to a new full_topic topic, creating a collection and reassigning the notes" do
          new_topic =
            topic1.move_posts(
              user1,
              [post1.id, post3.id],
              title: "New topic in ap category",
              category_id: category1.id,
            )

          expect([topic1.id, topic2.id, topic3.id]).not_to include(new_topic.id)
          expect(new_topic.first_post.raw).to eq(post1.raw)
          expect(post2.reload.topic_id).to eq(topic1.id)
          expect(new_topic.activity_pub_object.ap.collection?).to eq(true)
          expect(DiscourseActivityPubObject.count).to eq(3)
          expect(DiscourseActivityPubActivity.count).to eq(3)
          expect(note1.reload.model_id).to eq(new_topic.first_post.id)
          expect(note1.collection_id).to eq(new_topic.activity_pub_object.id)
          expect(note2.reload.collection_id).to eq(collection1.id)
        end

        it "moves the posts to an existing full_topic topic, reassigning the notes without creating records" do
          topic1.move_posts(user1, [post1.id, post3.id], destination_topic_id: topic2.id)

          first_post = topic2.reload.first_post
          expect(topic2.posts.size).to eq(2)
          expect(first_post.raw).to eq(post1.raw)
          expect(post2.reload.topic_id).to eq(topic1.id)
          expect(post3.reload.topic_id).to eq(topic2.id)
          expect(DiscourseActivityPubCollection.count).to eq(2)
          expect(DiscourseActivityPubObject.count).to eq(3)
          expect(DiscourseActivityPubActivity.count).to eq(3)
          expect(note1.reload.model_id).to eq(first_post.id)
          expect(note1.collection_id).to eq(collection2.id)
          expect(note2.reload.collection_id).to eq(collection1.id)
        end

        it "revives a tombstoned destination collection instead of failing to move posts in" do
          collection2.tombstone!

          expect {
            topic1.move_posts(user1, [post1.id, post3.id], destination_topic_id: topic2.id)
          }.not_to raise_error
          expect(DiscourseActivityPubCollection.all).to contain_exactly(collection1, collection2)
          expect(collection2.reload).not_to be_tombstoned
        end

        it "moves the posts to a new non-ap topic, clearing their note collections" do
          topic1.move_posts(
            user1,
            [post1.id, post3.id],
            title: "New topic in another category",
            category_id: category2.id,
          )

          new_topic = post3.reload.topic
          expect(new_topic.category_id).to eq(category2.id)
          expect(post2.reload.topic.category_id).to eq(category1.id)
          expect(DiscourseActivityPubCollection.count).to eq(2)
          expect(DiscourseActivityPubObject.count).to eq(3)
          expect(DiscourseActivityPubActivity.count).to eq(3)
          expect(note1.reload.model_id).to eq(new_topic.first_post.id)
          expect(note1.collection_id).to eq(nil)
          expect(note2.reload.collection_id).to eq(collection1.id)
        end

        it "moves the posts to an existing non-ap topic, clearing their note collections" do
          topic1.move_posts(
            user1,
            [post1.id, post3.id],
            destination_topic_id: topic3.id,
            category_id: category2.id,
          )

          first_post = topic3.first_post.reload
          expect(topic3.posts.size).to eq(2)
          expect(first_post.raw).to eq(post1.raw)
          expect(post2.reload.topic_id).to eq(topic1.id)
          expect(post3.reload.topic_id).to eq(topic3.id)
          expect(DiscourseActivityPubCollection.count).to eq(2)
          expect(DiscourseActivityPubObject.count).to eq(3)
          expect(DiscourseActivityPubActivity.count).to eq(3)
          expect(note1.reload.model_id).to eq(first_post.id)
          expect(note1.collection_id).to eq(nil)
          expect(note2.reload.collection_id).to eq(collection1.id)
        end
      end

      context "with first_post enabled" do
        before { toggle_activity_pub(category1, publication_type: "first_post") }

        it "moves the posts to a new first_post topic without creating a collection" do
          new_topic =
            topic1.move_posts(
              user1,
              [post1.id, post3.id],
              title: "New topic in ap category",
              category_id: category1.id,
            )

          expect([topic1.id, topic2.id, topic3.id]).not_to include(new_topic.id)
          expect(new_topic.first_post.raw).to eq(post1.raw)
          expect(post2.reload.topic_id).to eq(topic1.id)
          expect(new_topic.activity_pub_object).to eq(nil)
          expect(DiscourseActivityPubObject.count).to eq(1)
          expect(DiscourseActivityPubActivity.count).to eq(1)
          expect(note1.reload.model_id).to eq(new_topic.first_post.id)
        end

        it "moves the posts to an existing first_post topic without creating records" do
          topic1.move_posts(user1, [post1.id, post3.id], destination_topic_id: topic2.id)

          first_post = topic2.first_post
          expect(topic2.posts.size).to eq(2)
          expect(first_post.raw).to eq(post1.raw)
          expect(post2.reload.topic_id).to eq(topic1.id)
          expect(post3.reload.topic_id).to eq(topic2.id)
          expect(DiscourseActivityPubObject.count).to eq(1)
          expect(DiscourseActivityPubActivity.count).to eq(1)
          expect(note1.reload.model_id).to eq(first_post.reload.id)
        end

        it "moves the posts to a new non-ap topic" do
          topic1.move_posts(
            user1,
            [post1.id, post3.id],
            title: "New topic in another category",
            category_id: category2.id,
          )

          new_topic = post3.reload.topic
          expect(new_topic.category_id).to eq(category2.id)
          expect(post2.reload.topic.category_id).to eq(category1.id)
          expect(DiscourseActivityPubObject.count).to eq(1)
          expect(DiscourseActivityPubActivity.count).to eq(1)
          expect(note1.reload.model_id).to eq(new_topic.first_post.id)
        end

        it "moves the posts to an existing non-ap topic" do
          topic1.move_posts(
            user1,
            [post1.id, post3.id],
            destination_topic_id: topic3.id,
            category_id: category2.id,
          )

          first_post = topic3.first_post
          expect(topic3.posts.size).to eq(2)
          expect(first_post.raw).to eq(post1.raw)
          expect(post2.reload.topic_id).to eq(topic1.id)
          expect(post3.reload.topic_id).to eq(topic3.id)
          expect(DiscourseActivityPubObject.count).to eq(1)
          expect(DiscourseActivityPubActivity.count).to eq(1)
          expect(note1.reload.model_id).to eq(first_post.id)
        end
      end
    end

    context "with posts in a non ap category" do
      it "moves the posts to a new full_topic topic, creating a collection" do
        toggle_activity_pub(category2, publication_type: "full_topic")
        new_topic =
          topic1.move_posts(
            user1,
            [post1.id, post3.id],
            title: "New topic in ap category",
            category_id: category2.id,
          )

        expect([topic1.id, topic2.id, topic3.id]).not_to include(new_topic.id)
        expect(new_topic.first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic_id).to eq(topic1.id)
        expect(new_topic.activity_pub_object.ap.collection?).to eq(true)
        expect(DiscourseActivityPubObject.count).to eq(0)
        expect(DiscourseActivityPubActivity.count).to eq(0)
      end

      it "moves the posts to an existing full_topic topic without creating records" do
        Fabricate(:discourse_activity_pub_ordered_collection, model: topic3)
        toggle_activity_pub(category2, publication_type: "full_topic")
        topic1.move_posts(user1, [post1.id, post3.id], destination_topic_id: topic3.id)

        first_post = topic3.first_post
        expect(topic3.posts.size).to eq(2)
        expect(first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic_id).to eq(topic1.id)
        expect(post3.reload.topic_id).to eq(topic3.id)
        expect(DiscourseActivityPubCollection.count).to eq(1)
        expect(DiscourseActivityPubObject.count).to eq(0)
        expect(DiscourseActivityPubActivity.count).to eq(0)
      end

      it "moves the posts to a new first_post topic without creating a collection" do
        toggle_activity_pub(category2, publication_type: "first_post")
        new_topic =
          topic1.move_posts(
            user1,
            [post1.id, post3.id],
            title: "New topic in ap category",
            category_id: category2.id,
          )

        expect([topic1.id, topic2.id, topic3.id]).not_to include(new_topic.id)
        expect(new_topic.first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic_id).to eq(topic1.id)
        expect(new_topic.activity_pub_object).to eq(nil)
        expect(DiscourseActivityPubObject.count).to eq(0)
        expect(DiscourseActivityPubActivity.count).to eq(0)
      end

      it "moves the posts to an existing first_post topic without creating records" do
        toggle_activity_pub(category2, publication_type: "first_post")
        topic1.move_posts(user1, [post1.id, post3.id], destination_topic_id: topic3.id)

        first_post = topic3.first_post
        expect(topic3.posts.size).to eq(2)
        expect(first_post.raw).to eq(post1.raw)
        expect(post2.reload.topic_id).to eq(topic1.id)
        expect(post3.reload.topic_id).to eq(topic3.id)
        expect(DiscourseActivityPubCollection.count).to eq(0)
        expect(DiscourseActivityPubObject.count).to eq(0)
        expect(DiscourseActivityPubActivity.count).to eq(0)
      end
    end
  end
end
