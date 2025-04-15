# frozen_string_literal: true

RSpec.describe UserDestroyer do
  let!(:user) { Fabricate(:user) }

  describe "#destroy" do
    context "when user is associated with an ActivityPub actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, model: user) }
      let!(:note1) { Fabricate(:discourse_activity_pub_object_note, attributed_to: actor) }
      let!(:note2) { Fabricate(:discourse_activity_pub_object_note, attributed_to: actor) }
      let!(:activity1) do
        Fabricate(:discourse_activity_pub_activity_create, object: note1, actor: actor)
      end
      let!(:activity2) do
        Fabricate(:discourse_activity_pub_activity_create, object: note2, actor: actor)
      end

      before { UserDestroyer.new(user).destroy(user) }

      it "tombstones the actor" do
        expect(actor.reload.tombstoned?).to eq(true)
      end

      it "does not destroy the actor's activities" do
        expect(DiscourseActivityPubActivity.exists?(activity1.id)).to eq(true)
        expect(DiscourseActivityPubActivity.exists?(activity2.id)).to eq(true)
      end

      it "tombstones objects of the actor's activities" do
        expect(note1.reload.tombstoned?).to eq(true)
        expect(note2.reload.tombstoned?).to eq(true)
      end
    end
  end
end
