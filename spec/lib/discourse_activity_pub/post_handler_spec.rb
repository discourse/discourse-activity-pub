# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::PostHandler do
  describe "#create" do
    let!(:user) { Fabricate(:user) }
    let(:category) { Fabricate(:category) }
    let(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
    let!(:object) { Fabricate(:discourse_activity_pub_object_note, model: nil, reply_to_id: note.ap_id) }

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

      context "when given a category id" do
        context "when activity pub full topic is ready" do
          before do
            toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
          end

          it "creates a topic in the category" do
            post = described_class.create(user, object, category_id: category.id)
            expect(post.present?).to eq(true)
            expect(post.topic.present?).to eq(true)
            expect(post.topic.category_id).to eq(category.id)
          end

          context "when the object has a context" do
            let!(:collection_ap_id) { "https://forum.com/ap/topic/1" }

            before do
              object.context = collection_ap_id
              object.save!
            end

            context "when the context is a collection" do
              let!(:collection_json) {
                {
                  "@context": "https://www.w3.org/ns/activitystreams",
                  "id": collection_ap_id,
                  "type": "OrderedCollection",
                }.with_indifferent_access
              }

              before do
                stub_request(:get, collection_ap_id)
                  .with(headers: { 'Accept' => DiscourseActivityPub::JsonLd.content_type_header } )
                  .to_return(
                    status: 200,
                    body: collection_json.to_json,
                    headers: {
                      'Content-Type' => DiscourseActivityPub::JsonLd.content_type_header
                    }
                  )
              end

              it "resolves and stores it as the topic collection" do
                post = described_class.create(user, object, category_id: category.id)
                expect(object.reload.collection.present?).to eq(true)
                expect(object.collection.local).to eq(false)
                expect(object.collection.ap_id).to eq(collection_ap_id)
                expect(object.collection.model.id).to eq(post.topic.id)
              end
            end
          end

          context "when the object does not have a context" do
            it "creates a new local topic collection" do
              post = described_class.create(user, object, category_id: category.id)
              expect(object.reload.collection.present?).to eq(true)
              expect(object.collection.local).to eq(true)
              expect(object.collection_id).to eq(post.topic.activity_pub_object.id)
              expect(object.collection.model.id).to eq(post.topic.id)
            end
          end
        end

        context "when activity pub full topic is not ready" do
          it "does nothing" do
            expect(described_class.create(user, object, category_id: category.id)).to eq(nil)
          end
        end
      end

      context "when not given a category id" do
        it "does nothing" do
          expect(described_class.create(user, object)).to eq(nil)
        end
      end
    end

    context "when object is in reply to another object" do
      before do
        topic.create_activity_pub_collection!
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
end