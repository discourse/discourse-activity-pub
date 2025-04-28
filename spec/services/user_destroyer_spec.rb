# frozen_string_literal: true

RSpec.describe UserDestroyer do
  let!(:user) { Fabricate(:user) }

  describe "#destroy" do
    context "when user is associated with a local ActivityPub actor" do
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

      it "destroys the actor" do
        expect(DiscourseActivityPubActor.unscoped.exists?(actor.id)).to eq(false)
      end

      it "destroys the actor's activities" do
        expect(DiscourseActivityPubActivity.unscoped.exists?(activity1.id)).to eq(false)
        expect(DiscourseActivityPubActivity.unscoped.exists?(activity2.id)).to eq(false)
      end

      it "destroys the objects of the actor's activities" do
        expect(DiscourseActivityPubObject.unscoped.exists?(note1.id)).to eq(false)
        expect(DiscourseActivityPubObject.unscoped.exists?(note2.id)).to eq(false)
      end
    end
  end
end
