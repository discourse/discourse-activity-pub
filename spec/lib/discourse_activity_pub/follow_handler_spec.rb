# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::FollowHandler do

  describe "#follow" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

    def perform(actor_id, target_actor_id)
      DiscourseActivityPub::FollowHandler.follow(actor_id, target_actor_id)
    end

    context "when actor being followed does not exist" do
      it "returns false" do
        expect(perform(actor.id, actor.id + 50)).to eq(false)
      end
    end

    context "with a local target actor" do
      let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_group, local: true) }

      it "does not perform a follow action" do
        expect(perform(actor.id, target_actor.id)).to eq(false)
      end
    end
    
    context "with a remote target actor" do
      let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

      it "creates a follow activity" do
        perform(actor.id, target_actor.id)
        expect(
          DiscourseActivityPubActivity.exists?(
              local: true,
              actor_id: actor.id,
              object_id: target_actor.id,
              object_type: target_actor.class.name,
              ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
          )
        ).to eq(true)
      end

      it "performs the right delivery" do
        expect_delivery(
          actor: actor,
          object_type: DiscourseActivityPub::AP::Activity::Follow.type,
          recipient_ids: [target_actor.id]
        )
        perform(actor.id, target_actor.id)
      end
    end
  end

  describe "#unfollow" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

    def perform(actor_id, target_actor_id)
      DiscourseActivityPub::FollowHandler.unfollow(actor_id, target_actor_id)
    end

    context "when actor being followed does not exist" do
      it "returns false" do
        expect(perform(actor.id, actor.id + 50)).to eq(false)
      end
    end

    context "with a local target actor" do
      let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_group, local: true) }

      it "does not perform an unfollow action" do
        expect(perform(actor.id, target_actor.id)).to eq(false)
      end
    end

    context "with a remote target actor" do
      let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

      context "without a follow activity" do
        it "returns false" do
          expect(perform(actor.id, target_actor.id)).to eq(false)
        end
      end

      context "with a published follow activity" do
        let!(:follow_activity) {
          Fabricate(:discourse_activity_pub_activity_follow,
            local: true,
            actor: actor,
            object: target_actor,
            published_at: Time.now
          )
        }

        context "when the actor is following the target actor" do
          let!(:follow) {
            Fabricate(:discourse_activity_pub_follow,
              follower: actor,
              followed: target_actor
            )
          }

          it "creates an undo activity" do
            perform(actor.id, target_actor.id)
            expect(
              DiscourseActivityPubActivity.exists?(
                  local: true,
                  actor_id: actor.id,
                  object_id: follow_activity.id,
                  object_type: follow_activity.class.name,
                  ap_type: DiscourseActivityPub::AP::Activity::Undo.type,
              )
            ).to eq(true)
          end
    
          it "performs the right delivery" do
            expect_delivery(
              actor: actor,
              object_type: DiscourseActivityPub::AP::Activity::Undo.type,
              recipient_ids: [target_actor.id]
            )
            perform(actor.id, target_actor.id)
          end

          it "doesn't destroy the follow" do
            expect(follow.destroyed?).to eq(false)
          end
        end

        context "when the actor is not following the target actor" do
          it "returns false" do
            expect(perform(actor.id, target_actor.id)).to eq(false)
          end
        end
      end
    end
  end
end