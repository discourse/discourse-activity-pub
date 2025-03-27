# frozen_string_literal: true

RSpec.describe PostAction do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:collection) do
    Fabricate(:discourse_activity_pub_ordered_collection, local: false, model: topic)
  end
  let!(:user) { Fabricate(:user) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person, model: user) }
  let!(:post) { Fabricate(:post, topic: topic, user: user) }
  let!(:note) do
    Fabricate(
      :discourse_activity_pub_object_note,
      model: post,
      local: false,
      collection_id: collection.id,
      attributed_to: person,
    )
  end
  let!(:user2) { Fabricate(:user) }
  let!(:person2) { Fabricate(:discourse_activity_pub_actor_person, model: user2) }
  let!(:post_action) do
    Fabricate(
      :post_action,
      user: user2,
      post: post,
      post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
    )
  end

  describe "#perform_activity_pub_activity" do
    context "without activty pub enabled on the category" do
      it "does nothing" do
        expect(post_action.perform_activity_pub_activity(:like)).to eq(false)
        expect(post.activity_pub_object.reload.likes.present?).to eq(false)
      end
    end

    context "with an invalid activity type" do
      it "does nothing" do
        expect(post_action.perform_activity_pub_activity(:create)).to eq(false)
        expect(post.activity_pub_object.reload.likes.present?).to eq(false)
      end
    end

    context "with first_post enabled on the category" do
      before do
        toggle_activity_pub(category, publication_type: "first_post")
        post_action.reload
      end

      it "does nothing" do
        expect(post_action.perform_activity_pub_activity(:like)).to eq(false)
        expect(post.activity_pub_object.reload.likes.any?).to eq(false)
      end
    end

    context "with full_topic enabled on the category" do
      before { toggle_activity_pub(category, publication_type: "full_topic") }

      context "with like" do
        def perform_like
          post_action.perform_activity_pub_activity(:like)
        end

        it "creates the right activity" do
          perform_like
          expect(
            post_action
              .activity_pub_actor
              .activities
              .where(
                object_id: post.activity_pub_object.id,
                object_type: "DiscourseActivityPubObject",
                ap_type: "Like",
              )
              .exists?,
          ).to eq(true)
        end

        context "while topic is not published" do
          it "does not send anything for delivery" do
            expect_no_delivery
            perform_like
          end
        end

        context "after topic publication" do
          before do
            post.custom_fields["activity_pub_published_at"] = Time.now
            post.save_custom_fields(true)
          end

          context "when the topic has remote contributors" do
            before { post.reload.activity_pub_actor.update(local: false) }

            it "sends to the remote contributors for delivery without delay" do
              expect_delivery(
                actor: category.activity_pub_actor,
                object_type: "Like",
                recipient_ids: [person.id],
              )
              perform_like
            end

            context "when the category has followers" do
              let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
              let!(:follow1) do
                Fabricate(
                  :discourse_activity_pub_follow,
                  follower: follower1,
                  followed: category.activity_pub_actor,
                )
              end

              it "sends to followers and remote contributors for delivery without delay" do
                expect_delivery(
                  actor: category.activity_pub_actor,
                  object_type: "Like",
                  recipient_ids: [follower1.id] + [person.id],
                )
                perform_like
              end
            end
          end
        end
      end

      context "with undo like" do
        let!(:like) do
          Fabricate(:discourse_activity_pub_activity_like, actor: person2, object: note)
        end

        def perform_undo_like
          post_action.perform_activity_pub_activity(:undo, :like)
        end

        it "creates the right activity" do
          perform_undo_like
          expect(
            post_action
              .activity_pub_actor
              .activities
              .where(
                object_id: like.id,
                object_type: "DiscourseActivityPubActivity",
                ap_type: "Undo",
              )
              .exists?,
          ).to eq(true)
        end

        context "while topic is not published" do
          it "does not send anything for delivery" do
            expect_no_delivery
            perform_undo_like
          end
        end

        context "after topic publication" do
          before do
            post.custom_fields["activity_pub_published_at"] = Time.now
            post.save_custom_fields(true)
          end

          context "when the topic has remote contributors" do
            before { post.reload.activity_pub_actor.update(local: false) }

            it "sends to the remote contributors for delivery without delay" do
              expect_delivery(
                actor: category.activity_pub_actor,
                object_type: "Undo",
                recipient_ids: [person.id],
              )
              perform_undo_like
            end

            context "when the category has followers" do
              let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
              let!(:follow1) do
                Fabricate(
                  :discourse_activity_pub_follow,
                  follower: follower1,
                  followed: category.activity_pub_actor,
                )
              end

              it "sends to followers and remote contributors for delivery without delay" do
                expect_delivery(
                  actor: category.activity_pub_actor,
                  object_type: "Undo",
                  recipient_ids: [follower1.id] + [person.id],
                )
                perform_undo_like
              end
            end
          end
        end
      end
    end
  end
end
