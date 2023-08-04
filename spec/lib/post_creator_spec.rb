# frozen_string_literal: true

RSpec.describe PostCreator do
  let!(:user) { Fabricate(:user) }
  let!(:category) { Fabricate(:category) }
  let!(:params) do
    {
      title: "hello world topic",
      raw: "my name is angus",
      archetype_id: 1,
      advance_draft: true,
      category: category.id
    }
  end

  describe "create" do
    context "without a ready ActivityPub category" do
      context "when passed a visibility" do
        it "does not save the visibility" do
          post = PostCreator.create(user, params.merge(
            activity_pub_visibility: 'private'
          ))
          expect(post.custom_fields['activity_pub_visibility']).to eq(nil)
        end
      end

      context "when not passed a visibility" do
        it "does not save a visibility" do
          post = PostCreator.create(user, params)
          expect(post.custom_fields['activity_pub_visibility']).to eq(nil)
        end
      end
    end

    context "with a ready ActivityPub category" do
      before do
        toggle_activity_pub(category, callbacks: true)
      end

      context "when passed a visibility" do
        it "saves the category's default visibility" do
          post = PostCreator.create(user, params.merge(
            activity_pub_visibility: 'public'
          ))
          expect(post.custom_fields['activity_pub_visibility']).to eq(
            category.activity_pub_default_visibility
          )
        end
      end

      context "when not passed a visibility" do
        it "saves the category's default visibility" do
          post = PostCreator.create(user, params)
          expect(post.custom_fields['activity_pub_visibility']).to eq(
            category.activity_pub_default_visibility
          )
        end
      end

      context "with activity pub set to full topic on category" do
        before do
          toggle_activity_pub(category, publication_type: 'full_topic')
        end

        context "with the first post" do
          it "creates a topic collection" do
            post = PostCreator.create(user, params)
            expect(post.topic.activity_pub_object.ap_type).to eq(
              DiscourseActivityPub::AP::Collection::OrderedCollection.type
            )
            expect(post.topic.activity_pub_objects_collection.items.first.ap_id).to eq(
              post.activity_pub_object.ap_id
            )
            expect(post.activity_pub_object.collection_id).to eq(
              post.topic.activity_pub_object.ap_id
            )
          end
        end

        context "with a reply" do
          let!(:topic) { Fabricate(:topic, category: category)}
          let!(:post) { Fabricate(:post, topic: topic, post_number: 1) }

          before do
            post.custom_fields['activity_pub_visibility'] = 'public'
            post.save_custom_fields(true)
            topic.create_activity_pub_collection!
          end

          context "when passed a visibility" do
            it "saves the first post's visibility" do
              reply = PostCreator.create(user, params.merge(
                topic_id: topic.id,
                reply_to_post_number: 1,
                activity_pub_visibility: 'private'
              ))
              expect(reply.custom_fields['activity_pub_visibility']).to eq('public')
            end
          end

          context "when not passed a visibility" do
            it "saves the first post's visibility" do
              reply = PostCreator.create(user, params.merge(
                topic_id: topic.id,
                reply_to_post_number: 1
              ))
              expect(reply.custom_fields['activity_pub_visibility']).to eq(
                'public'
              )
            end
          end
        end
      end
    end
  end
end