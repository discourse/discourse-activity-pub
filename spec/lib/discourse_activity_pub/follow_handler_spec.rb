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
          ),
        ).to eq(true)
      end

      it "performs the right delivery" do
        expect_delivery(
          actor: actor,
          object_type: DiscourseActivityPub::AP::Activity::Follow.type,
          recipient_ids: [target_actor.id],
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
        let!(:follow_activity) do
          Fabricate(
            :discourse_activity_pub_activity_follow,
            local: true,
            actor: actor,
            object: target_actor,
            published_at: Time.now,
          )
        end

        context "when the actor is following the target actor" do
          let!(:follow) do
            Fabricate(:discourse_activity_pub_follow, follower: actor, followed: target_actor)
          end

          it "creates an undo activity" do
            perform(actor.id, target_actor.id)
            expect(
              DiscourseActivityPubActivity.exists?(
                local: true,
                actor_id: actor.id,
                object_id: follow_activity.id,
                object_type: follow_activity.class.name,
                ap_type: DiscourseActivityPub::AP::Activity::Undo.type,
              ),
            ).to eq(true)
          end

          it "performs the right delivery" do
            expect_delivery(
              actor: actor,
              object_type: DiscourseActivityPub::AP::Activity::Undo.type,
              recipient_ids: [target_actor.id],
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

  describe "#reject" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

    def perform(actor_id, target_actor_id)
      DiscourseActivityPub::FollowHandler.reject(actor_id, target_actor_id)
    end

    context "when the rejected follower does not exist" do
      it "returns false" do
        expect(perform(actor.id, actor.id + 50)).to eq(false)
      end
    end

    context "with a local rejected follower" do
      let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_group, local: true) }

      it "does not perform a reject action" do
        expect(perform(actor.id, target_actor.id)).to eq(false)
      end
    end

    context "with a remote rejected follower" do
      let!(:target_actor) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

      context "without a follow activity" do
        it "returns false" do
          expect(perform(actor.id, target_actor.id)).to eq(false)
        end
      end

      context "with a follow activity" do
        let!(:follow_activity) do
          Fabricate(
            :discourse_activity_pub_activity_follow,
            local: nil,
            actor: target_actor,
            object: actor,
            published_at: Time.now,
          )
        end

        context "with a follow" do
          let!(:follow) do
            Fabricate(:discourse_activity_pub_follow, follower: target_actor, followed: actor)
          end

          it "creates a reject activity" do
            perform(actor.id, target_actor.id)
            expect(
              DiscourseActivityPubActivity.exists?(
                local: true,
                actor_id: actor.id,
                object_id: follow_activity.id,
                object_type: follow_activity.class.name,
                ap_type: DiscourseActivityPub::AP::Activity::Reject.type,
              ),
            ).to eq(true)
          end

          it "performs the right delivery" do
            expect_delivery(
              actor: actor,
              object_type: DiscourseActivityPub::AP::Activity::Reject.type,
              recipient_ids: [target_actor.id],
            )
            perform(actor.id, target_actor.id)
          end

          it "destroys the follow" do
            perform(actor.id, target_actor.id)
            expect(DiscourseActivityPubFollow.exists?(follow.id)).to eq(false)
          end
        end

        context "without a follow" do
          it "returns false" do
            expect(perform(actor.id, target_actor.id)).to eq(false)
          end
        end
      end
    end
  end
end
