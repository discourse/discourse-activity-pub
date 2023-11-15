# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::FollowHandler do

  def perform(actor_id, follow_actor_id)
    DiscourseActivityPub::FollowHandler.perform(actor_id, follow_actor_id)
  end

  describe "#perform" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

    context "when actor being followed does not exist" do
      it "returns false" do
        expect(perform(actor.id, actor.id + 50)).to eq(false)
      end
    end

    context "with a local actor" do
      let!(:follow_actor) { Fabricate(:discourse_activity_pub_actor_group, local: true) }

      it "returns false" do
        expect(perform(actor.id, follow_actor.id)).to eq(false)
      end
    end

    
    context "with a remote actor" do
      let!(:follow_actor) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

      it "creates a follow activity" do
        perform(actor.id, follow_actor.id)
        expect(
          DiscourseActivityPubActivity.exists?(
              local: true,
              actor_id: actor.id,
              object_id: follow_actor.id,
              object_type: follow_actor.class.name,
              ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
          )
        ).to eq(true)
      end

      it "performs the right delivery" do
        expect_delivery(
          actor: actor,
          object_type: DiscourseActivityPub::AP::Activity::Follow.type,
          recipients: [follow_actor]
        )
        perform(actor.id, follow_actor.id)
      end
    end
  end
end