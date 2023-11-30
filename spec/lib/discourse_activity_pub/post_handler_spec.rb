# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::PostHandler do
  describe "#create" do
    let!(:user) { Fabricate(:user) }
    let(:category) { Fabricate(:category) }
    let(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
    let!(:object) do
      Fabricate(:discourse_activity_pub_object_note, model: nil, reply_to_id: note.ap_id)
    end

    before { topic.create_activity_pub_collection! }

    context "when object has a model" do
      before do
        reply = Fabricate(:post)
        object.update(model_id: reply.id, model_type: "Post")
      end

      it "does nothing" do
        expect(described_class.create(user, object)).to eq(nil)
      end
    end

    context "when object is not in reply to another object" do
      before { object.update(reply_to_id: nil) }

      it "does nothing" do
        expect(described_class.create(user, object)).to eq(nil)
      end
    end

    it "skips validations and events" do
      PostCreator
        .expects(:create!)
        .with { |user, opts| opts[:skip_validations] && opts[:skip_events] }
      described_class.create(user, object)
    end

    it "creates a reply for a reply object" do
      reply = described_class.create(user, object)
      expect(reply.raw).to eq(object.content)
      expect(reply.topic_id).to eq(topic.id)
      expect(reply.reply_to_post_number).to eq(post.post_number)
    end

    it "updates the reply object correclty" do
      reply = described_class.create(user, object)
      object.reload
      expect(object.model_id).to eq(reply.id)
      expect(object.model_type).to eq("Post")
      expect(object.collection_id).to eq(topic.activity_pub_object.id)
    end
  end
end
