# frozen_string_literal: true

RSpec.describe Category do
  let(:category) { Fabricate(:category) }

  it { is_expected.to have_one(:activity_pub_actor).dependent(:destroy) }

  describe "#activity_pub_ready?" do
    context "without an activity pub actor" do
      it "returns false" do
        expect(category.activity_pub_ready?).to eq(false)
      end
    end

    context "with an activity pub actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }

      before { toggle_activity_pub(category) }

      it "returns true" do
        expect(category.reload.activity_pub_ready?).to eq(true)
      end

      context "with category read restricted" do
        before do
          category.set_permissions(staff: :full)
          category.save!
        end

        it "returns false" do
          expect(category.reload.activity_pub_ready?).to eq(false)
        end
      end
    end
  end

  describe "#activity_pub_publish_state" do
    it "publishes status to all users" do
      message =
        MessageBus.track_publish("/activity-pub") { category.activity_pub_publish_state }.first
      expect(message.group_ids).to eq(nil)
    end
  end

  describe "#activity_pub_delete!" do
    let!(:category_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
    let!(:note1) { Fabricate(:discourse_activity_pub_object_note, attributed_to: category_actor) }
    let!(:note2) { Fabricate(:discourse_activity_pub_object_note, attributed_to: category_actor) }
    let!(:follower1) { Fabricate(:discourse_activity_pub_actor_person) }
    let!(:follow1) do
      Fabricate(:discourse_activity_pub_follow, follower: follower1, followed: category_actor)
    end
    let!(:follower2) { Fabricate(:discourse_activity_pub_actor_person) }
    let!(:follow2) do
      Fabricate(:discourse_activity_pub_follow, follower: follower2, followed: category_actor)
    end

    before { toggle_activity_pub(category) }

    it "creates the right activity" do
      category.activity_pub_delete!
      expect(category_actor.activities.where(ap_type: "Delete").exists?).to eq(true)
    end

    it "tombstones associated objects" do
      category.activity_pub_delete!
      expect(category_actor.reload.ap_type).to eq("Tombstone")
      expect(category_actor.reload.ap_former_type).to eq("Group")
      expect(note1.reload.ap_type).to eq("Tombstone")
      expect(note1.reload.ap_former_type).to eq("Note")
      expect(note2.reload.ap_type).to eq("Tombstone")
      expect(note2.reload.ap_former_type).to eq("Note")
    end

    it "sends to followers for delivery without delay" do
      expect_delivery(
        actor: category_actor,
        object_type: "Delete",
        recipient_ids: [follower1.id, follower2.id],
      )
      category.activity_pub_delete!
    end
  end
end
