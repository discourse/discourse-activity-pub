# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::PostHandler do
  describe "#create" do
    let!(:user) { Fabricate(:user) }
    let(:category) { Fabricate(:category) }
    let(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
    let!(:object) { Fabricate(:discourse_activity_pub_object_note, model: nil, reply_to_id: note.ap_id) }

    before do
      topic.create_activity_pub_collection!
    end

    context "when object has a model" do
      before do
        reply = Fabricate(:post)
        object.update(model_id: reply.id, model_type: 'Post')
      end

      it "does nothing" do
        expect(described_class.create(user, object)).to eq(nil)
      end
    end

    context "when object is not in reply to another object" do
      before do
        object.update(reply_to_id: nil)
      end

      context "when given a target category actor" do
        context "when activity pub full topic is ready" do
          before do
            toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
          end

          it "creates a topic in the category" do
            post = described_class.create(user, object, category.activity_pub_actor)
            expect(post.present?).to eq(true)
            expect(post.topic.present?).to eq(true)
            expect(post.topic.category_id).to eq(category.id)
            expect(object.reload.collection_id).to eq(post.topic.activity_pub_object.id)
          end
        end

        context "when activity pub full topic is not ready" do
          it "does nothing" do
            expect(described_class.create(user, object, category.activity_pub_actor)).to eq(nil)
          end
        end
      end

      context "when not given a target category actor" do
        it "does nothing" do
          expect(described_class.create(user, object)).to eq(nil)
        end
      end
    end

    it "skips validations and events" do
      PostCreator
        .expects(:create!)
        .with do |user, opts|
          opts[:skip_validations] && opts[:skip_events]
        end
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