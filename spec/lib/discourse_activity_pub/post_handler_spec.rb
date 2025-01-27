# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::PostHandler do
  describe "#create" do
    let!(:user) { Fabricate(:user) }
    let!(:category) { Fabricate(:category) }
    let!(:tag) { Fabricate(:tag) }
    let!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post) }
    let!(:object) do
      Fabricate(:discourse_activity_pub_object_note, model: nil, reply_to_id: note.ap_id)
    end

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

      context "when given a category id" do
        context "when activity pub full topic is ready" do
          before { toggle_activity_pub(category, publication_type: "full_topic") }

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
              let!(:collection_json) do
                {
                  "@context": "https://www.w3.org/ns/activitystreams",
                  id: collection_ap_id,
                  type: "OrderedCollection",
                }.with_indifferent_access
              end

              before do
                stub_request(:get, collection_ap_id).with(
                  headers: {
                    "Accept" => DiscourseActivityPub::JsonLd.content_type_header,
                  },
                ).to_return(
                  status: 200,
                  body: collection_json.to_json,
                  headers: {
                    "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
                  },
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

      context "when given a tag id" do
        context "when activity pub full topic is ready" do
          before { toggle_activity_pub(tag, publication_type: "full_topic") }

          it "creates a topic in the category" do
            post = described_class.create(user, object, tag_id: tag.id)
            expect(post.present?).to eq(true)
            expect(post.topic.present?).to eq(true)
            expect(post.topic.tags&.map(&:id)&.include?(tag.id)).to eq(true)
          end

          context "when the object has a context" do
            let!(:collection_ap_id) { "https://forum.com/ap/topic/1" }

            before do
              object.context = collection_ap_id
              object.save!
            end

            context "when the context is a collection" do
              let!(:collection_json) do
                {
                  "@context": "https://www.w3.org/ns/activitystreams",
                  id: collection_ap_id,
                  type: "OrderedCollection",
                }.with_indifferent_access
              end

              before do
                stub_request(:get, collection_ap_id).with(
                  headers: {
                    "Accept" => DiscourseActivityPub::JsonLd.content_type_header,
                  },
                ).to_return(
                  status: 200,
                  body: collection_json.to_json,
                  headers: {
                    "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
                  },
                )
              end

              it "resolves and stores it as the topic collection" do
                post = described_class.create(user, object, tag_id: tag.id)
                expect(object.reload.collection.present?).to eq(true)
                expect(object.collection.local).to eq(false)
                expect(object.collection.ap_id).to eq(collection_ap_id)
                expect(object.collection.model.id).to eq(post.topic.id)
              end
            end
          end

          context "when the object does not have a context" do
            it "creates a new local topic collection" do
              post = described_class.create(user, object, tag_id: tag.id)
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

      context "when not given a category id or tag" do
        it "does nothing" do
          expect(described_class.create(user, object)).to eq(nil)
        end
      end
    end

    context "when object is in reply to another object" do
      before { topic.create_activity_pub_collection! }

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

      context "when inReplyTo object is not present" do
        before do
          toggle_activity_pub(category, publication_type: "full_topic")
          note.destroy!
        end

        it "does nothing" do
          expect(described_class.create(user, object, category_id: category.id)).to eq(nil)
        end
      end
    end
  end
end
