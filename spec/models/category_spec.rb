# frozen_string_literal: true

RSpec.describe Category do
  let(:category) { Fabricate(:category) }

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

    it "sends to followers for delivery without delay" do
      expect_delivery(
        actor: category_actor,
        object_type: "Delete",
        recipient_ids: [follower1.id, follower2.id],
      )
      category.activity_pub_delete!
    end

    context "when category is not destroyed" do
      it "tombstones associated objects" do
        category.activity_pub_delete!
        expect(category_actor.reload.tombstoned?).to eq(true)
        expect(note1.reload.tombstoned?).to eq(true)
      end
    end
  end

  describe "destroy!" do
    let!(:category_actor) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
    let!(:note1) { Fabricate(:discourse_activity_pub_object_note, attributed_to: category_actor) }

    before { toggle_activity_pub(category) }

    it "destroys the associated objects" do
      category.destroy!
      expect(DiscourseActivityPubActor.exists?(category_actor.id)).to eq(false)
      expect(DiscourseActivityPubObject.exists?(note1.id)).to eq(false)
    end

    it "calls activity_pub_delete!" do
      Category.any_instance.expects(:activity_pub_delete!).once
      category.destroy!
    end
  end
end
