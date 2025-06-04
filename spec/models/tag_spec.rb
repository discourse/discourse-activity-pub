# frozen_string_literal: true

RSpec.describe Tag do
  let(:tag) { Fabricate(:tag) }

  describe "#activity_pub_ready?" do
    context "without an activity pub actor" do
      it "returns false" do
        expect(tag.activity_pub_ready?).to eq(false)
      end
    end

    context "with an activity pub actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: tag) }

      before { toggle_activity_pub(tag) }

      it "returns true" do
        expect(tag.reload.activity_pub_ready?).to eq(true)
      end
    end
  end

  describe "#activity_pub_publish_state" do
    it "publishes status to all users" do
      message = MessageBus.track_publish("/activity-pub") { tag.activity_pub_publish_state }.first
      expect(message.group_ids).to eq(nil)
    end
  end

  describe "#activity_pub_delete!" do
    let!(:tag_actor) { Fabricate(:discourse_activity_pub_actor_group, model: tag) }
    let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
    let!(:follow1) do
      Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: tag_actor)
    end
    let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
    let!(:follow2) do
      Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: tag_actor)
    end

    before { toggle_activity_pub(tag) }

    it "creates the right activity" do
      tag.activity_pub_delete!
      expect(tag_actor.activities.where(ap_type: "Delete").exists?).to eq(true)
    end

    it "sends to followers for delivery without delay" do
      expect_delivery(
        actor: tag_actor,
        object_type: "Delete",
        recipient_ids: [follower1.id, follower2.id],
      )
      tag.activity_pub_delete!
    end
  end

  describe "destroy!" do
    let!(:tag_actor) { Fabricate(:discourse_activity_pub_actor_group, model: tag) }
    let!(:note1) { Fabricate(:discourse_activity_pub_object_note, attributed_to: tag_actor) }
    let!(:note2) { Fabricate(:discourse_activity_pub_object_note, attributed_to: tag_actor) }

    before { toggle_activity_pub(tag) }

    it "destroys the associated objects" do
      tag.destroy!
      expect(DiscourseActivityPubActor.exists?(tag_actor.id)).to eq(false)
      expect(DiscourseActivityPubObject.exists?(note1.id)).to eq(false)
      expect(DiscourseActivityPubObject.exists?(note2.id)).to eq(false)
    end

    it "calls activity_pub_delete!" do
      Tag.any_instance.expects(:activity_pub_delete!).once
      tag.destroy!
    end
  end
end
