# frozen_string_literal: true
RSpec.describe "integration cases" do
  def read_json(case_name, file_name)
    JSON.parse(
      File.open(
        File.join(
          File.expand_path("../..", __dir__),
          "spec",
          "fixtures",
          "integration",
          case_name,
          "#{file_name}.json",
        ),
      ).read,
    ).with_indifferent_access
  end

  describe "#case 1" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
    let!(:remote_actor) do
      json = read_json("case_1", "group_actor")
      Fabricate(:discourse_activity_pub_actor_group, ap_id: json[:id], local: false)
    end
    let!(:follow) do
      Fabricate(:discourse_activity_pub_follow, follower: actor, followed: remote_actor)
    end

    before do
      toggle_activity_pub(actor.model, publication_type: "full_topic")
      Jobs.run_immediately!
      SiteSetting.activity_pub_require_signed_requests = false

      stub_object_request(read_json("case_1", "group_actor"))
      stub_object_request(read_json("case_1", "actor_1"))
      stub_object_request(read_json("case_1", "actor_2"))
      stub_object_request(read_json("case_1", "actor_3"))
      stub_object_request(read_json("case_1", "actor_4"))
      stub_object_request(read_json("case_1", "actor_5"))
      stub_object_request(read_json("case_1", "context_1"))

      post_to_inbox(actor, body: read_json("case_1", "received_1"))
      post_to_inbox(actor, body: read_json("case_1", "received_2"))
      post_to_inbox(actor, body: read_json("case_1", "received_3"))
      post_to_inbox(actor, body: read_json("case_1", "received_4"))
      post_to_inbox(actor, body: read_json("case_1", "received_5"))
      post_to_inbox(actor, body: read_json("case_1", "received_6"))
      post_to_inbox(actor, body: read_json("case_1", "received_7"))
      post_to_inbox(actor, body: read_json("case_1", "received_8"))
      post_to_inbox(actor, body: read_json("case_1", "received_9"))
      post_to_inbox(actor, body: read_json("case_1", "received_10"))
    end

    it "creates the right Discourse objects" do
      user = User.find_by(name: "FrankM")
      post = Post.find_by("raw LIKE ?", "%I thought that if I entered a Fediverse address here%")
      topic = Topic.find_by(title: "Is ActivityPub too complicated?")
      expect(post.present?).to eq(true)
      expect(topic.present?).to eq(true)
      expect(post.topic_id).to eq(topic.id)
      expect(topic.category_id).to eq(actor.model.id)
      expect(post.like_count).to eq(4)
    end

    it "creates the right AP objects" do
      post = Post.find_by("raw LIKE ?", "%I thought that if I entered a Fediverse address here%")
      topic = Topic.find_by(title: "Is ActivityPub too complicated?")
      expect(DiscourseActivityPubCollection.where(model_id: topic.id).count).to eq(1)
      expect(DiscourseActivityPubObject.where(model_id: post.id).count).to eq(1)
      expect(DiscourseActivityPubActor.where(ap_type: "Person").count).to eq(5)
      expect(DiscourseActivityPubActivity.where(ap_type: "Announce").count).to eq(5)
      expect(DiscourseActivityPubActivity.where(ap_type: "Like").count).to eq(4)
    end
  end

  describe "#case 2" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }
    let!(:remote_actor) do
      json = read_json("case_2", "group_actor")
      Fabricate(:discourse_activity_pub_actor_group, ap_id: json[:id], local: false)
    end
    let!(:follow) do
      Fabricate(:discourse_activity_pub_follow, follower: actor, followed: remote_actor)
    end

    before do
      toggle_activity_pub(actor.model, publication_type: "full_topic")
      Jobs.run_immediately!
      SiteSetting.activity_pub_require_signed_requests = false

      stub_object_request(read_json("case_2", "group_actor"))
      stub_object_request(read_json("case_2", "actor_1"))
      stub_object_request(read_json("case_2", "actor_2"))
      stub_object_request(read_json("case_2", "actor_3"))
      stub_object_request(read_json("case_2", "context_1"))

      threads = []
      results = []
      6.times do |index|
        threads << Thread.new do
          post_to_inbox(actor, body: read_json("case_2", "received_#{index + 1}"))
          results << response
          sleep 0.01
        end
      end
      threads.each(&:join)
    end

    it "creates the right Discourse objects" do
      posts = Post.all
      topics = Topic.all
      expect(posts.size).to eq(1)
      expect(topics.size).to eq(1)
      expect(posts.first.topic_id).to eq(topics.first.id)
      expect(posts.first.like_count).to eq(2)
      expect(topics.first.category_id).to eq(actor.model.id)
    end

    it "creates the right AP objects" do
      expect(DiscourseActivityPubCollection.where(ap_type: "OrderedCollection").count).to eq(1)
      expect(DiscourseActivityPubObject.where(ap_type: "Note").count).to eq(1)
      expect(DiscourseActivityPubActor.where(ap_type: "Person").count).to eq(3)
      expect(DiscourseActivityPubActivity.where(ap_type: "Announce").count).to eq(3)
      expect(DiscourseActivityPubActivity.where(ap_type: "Like").count).to eq(2)
    end
  end
end
