# frozen_string_literal: true

RSpec.describe "ActivityPub Multisite", type: :multisite do
  before { Jobs.run_immediately! }

  context "when processing" do
    def fabricate_follow(actor)
      remote_actor_json = read_integration_json("case_2", "group_actor")
      remote_actor = Fabricate(:discourse_activity_pub_actor_group, ap_id: remote_actor_json[:id], local: false)
      Fabricate(:discourse_activity_pub_follow, follower: actor, followed: remote_actor)
    end

    def process_json(json, actor)
      Jobs::DiscourseActivityPubProcess.new.execute(
        json: json,
        delivered_to: actor.ap_id
      )
    end

    def process_case(actor)
      stub_object_request(read_integration_json("case_2", "group_actor"))
      stub_object_request(read_integration_json("case_2", "actor_1"))
      stub_object_request(read_integration_json("case_2", "actor_2"))
      stub_object_request(read_integration_json("case_2", "actor_3"))
      stub_object_request(read_integration_json("case_2", "context_1"))

      6.times do |index|
        process_json(read_integration_json("case_2", "received_#{index + 1}"), actor)
      end
    end

    it "creates the right objects" do
      test_multisite_connection("default") do
        actor = Fabricate(:discourse_activity_pub_actor_group)
        fabricate_follow(actor)
        toggle_activity_pub(actor.model, publication_type: "full_topic")

        process_case(actor)

        posts = Post.all
        topics = Topic.all
        expect(posts.size).to eq(1)
        expect(topics.size).to eq(1)
        expect(posts.first.topic_id).to eq(topics.first.id)
        expect(topics.first.category_id).to eq(actor.model.id)
        expect(DiscourseActivityPubCollection.where(ap_type: "OrderedCollection").count).to eq(1)
        expect(DiscourseActivityPubObject.where(ap_type: "Note").count).to eq(1)
        expect(DiscourseActivityPubActor.where(ap_type: "Person").count).to eq(3)
        expect(DiscourseActivityPubActivity.where(ap_type: "Announce").count).to eq(3)
      end

      test_multisite_connection("second") do
        actor = Fabricate(:discourse_activity_pub_actor_group)
        fabricate_follow(actor)
        toggle_activity_pub(actor.model, publication_type: "full_topic")

        process_case(actor)

        posts = Post.all
        topics = Topic.all
        expect(posts.size).to eq(1)
        expect(topics.size).to eq(1)
        expect(posts.first.topic_id).to eq(topics.first.id)
        expect(topics.first.category_id).to eq(actor.model.id)
        expect(DiscourseActivityPubCollection.where(ap_type: "OrderedCollection").count).to eq(1)
        expect(DiscourseActivityPubObject.where(ap_type: "Note").count).to eq(1)
        expect(DiscourseActivityPubActor.where(ap_type: "Person").count).to eq(3)
        expect(DiscourseActivityPubActivity.where(ap_type: "Announce").count).to eq(3)
      end
    end
  end

  context "when publishing" do
    def fabricate_post(category)
      topic = Fabricate(:topic, category: category)
      Fabricate(:post, topic: topic)
    end

    def fabricate_follower(category)
      follower = Fabricate(:discourse_activity_pub_actor_person)
      Fabricate(
        :discourse_activity_pub_follow,
        follower: follower,
        followed: category.activity_pub_actor,
      )
      follower
    end

    before do
      ENV["ACTIVITY_PUB_DISABLE_DELIVERY_RETRIES"] = "true"
    end

    it "sends activities to followers" do
      test_multisite_connection("default") do
        category = Fabricate(:category)
        toggle_activity_pub(category, publication_type: "full_topic")
        follower = fabricate_follower(category)

        expect_request(actor_id: category.activity_pub_actor.id, uri: follower.inbox)

        post = fabricate_post(category)
        post.activity_pub_publish!
      end

      test_multisite_connection("second") do
        category = Fabricate(:category)
        toggle_activity_pub(category, publication_type: "full_topic")
        follower = fabricate_follower(category)

        expect_request(actor_id: category.activity_pub_actor.id, uri: follower.inbox)

        post = fabricate_post(category)
        post.activity_pub_publish!
      end
    end
  end
end
