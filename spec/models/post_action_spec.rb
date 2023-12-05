# frozen_string_literal: true

RSpec.describe PostAction do
  let!(:category) { Fabricate(:category) }
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection, local: false, model: topic) }
  let!(:user) { Fabricate(:user) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person, model: user) }
  let!(:post) { Fabricate(:post, topic: topic, user: user) }
  let!(:note) { Fabricate(:discourse_activity_pub_object_note, model: post, local: false, collection_id: collection.id) }
  let!(:user2) { Fabricate(:user) }
  let!(:person2) { Fabricate(:discourse_activity_pub_actor_person, model: user2) }
  let!(:post_action) { Fabricate(:post_action, user: user2, post: post, post_action_type_id: PostActionType.types[:like]) }

  describe "#perform_activity_pub_activity" do
    context "without activty pub enabled on the category" do
      it "does nothing" do
        expect(post_action.perform_activity_pub_activity(:like)).to eq(nil)
        expect(post.activity_pub_object.reload.likes.present?).to eq(false)
      end
    end

    context "with an invalid activity type" do
      it "does nothing" do
        expect(post_action.perform_activity_pub_activity(:create)).to eq(nil)
        expect(post.activity_pub_object.reload.likes.present?).to eq(false)
      end
    end

    context "with first_post enabled on the category" do
      before do
        toggle_activity_pub(category, callbacks: true)
        post_action.reload
      end

      it "does nothing" do
        expect(post_action.perform_activity_pub_activity(:like)).to eq(nil)
        expect(post.activity_pub_object.reload.likes.any?).to eq(false)
      end
    end

    context "with full_topic enabled on the category" do
      before do
        toggle_activity_pub(category, callbacks: true, publication_type: 'full_topic')
      end

      context "with like" do
        def perform_like
          post_action.perform_activity_pub_activity(:like)
        end

        it "creates the right activity" do
          perform_like
          expect(
             post_action.activity_pub_actor.activities.where(
               object_id: post.activity_pub_object.id,
               object_type: 'DiscourseActivityPubObject',
               ap_type: 'Like'
            ).exists?
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
            post.custom_fields['activity_pub_published_at'] = Time.now
            post.save_custom_fields(true)
          end

          it "sends the activity as the post action actor for delivery without delay" do
            expect_delivery(
              actor: post_action.activity_pub_actor,
              object_type: "Like"
            )
            perform_like
          end

          it "sends to the topic contributors for delivery without delay" do
            expect_delivery(
              actor: post_action.activity_pub_actor,
              object_type: "Like",
              recipient_ids: [post.activity_pub_actor.id]
            )
            perform_like
          end

          context "when category has followers" do
            let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category.activity_pub_actor) }

            it "sends to followers and topic contributors for delivery without delay" do
              expect_delivery(
                actor: post_action.activity_pub_actor,
                object_type: "Like",
                recipient_ids: [follower1.id] + [post.activity_pub_actor.id]
              )
              perform_like
            end
          end
        end
      end

      context "with undo like" do
        let!(:like) { Fabricate(:discourse_activity_pub_activity_like, actor: person2, object: note) }

        def perform_undo_like
          post_action.perform_activity_pub_activity(:undo, :like)
        end

        it "creates the right activity" do
          perform_undo_like
          expect(
             post_action.activity_pub_actor.activities.where(
               object_id: like.id,
               object_type: 'DiscourseActivityPubActivity',
               ap_type: 'Undo'
            ).exists?
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
            post.custom_fields['activity_pub_published_at'] = Time.now
            post.save_custom_fields(true)
          end

          it "sends to the topic contributors for delivery without delay" do
            expect_delivery(
              actor: post_action.activity_pub_actor,
              object_type: "Undo",
              recipient_ids: [post.activity_pub_actor.id]
            )
            perform_undo_like
          end

          context "when category has followers" do
            let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
            let!(:follow1) { Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category.activity_pub_actor) }

            it "sends to followers and topic contributors for delivery without delay" do
              expect_delivery(
                actor: post_action.activity_pub_actor,
                object_type: "Undo",
                recipient_ids: [follower1.id] + [post.activity_pub_actor.id]
              )
              perform_undo_like
            end
          end
        end
      end
    end
  end
end
