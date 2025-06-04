# frozen_string_literal: true

RSpec.describe UserMerger do
  let!(:target_user) { Fabricate(:user) }
  let!(:source_user) { Fabricate(:user) }

  describe "#merge!" do
    def merge_users!(source = nil, target = nil)
      source ||= source_user
      target ||= target_user
      UserMerger.new(source, target).merge!
    end

    context "when source user is associated with a remote actor" do
      let!(:actor) do
        Fabricate(:discourse_activity_pub_actor_person, model: source_user, local: false)
      end
      let!(:note1) { Fabricate(:discourse_activity_pub_object_note) }
      let!(:note2) { Fabricate(:discourse_activity_pub_object_note) }
      let!(:activity1) do
        Fabricate(:discourse_activity_pub_activity_create, object: note1, actor: actor)
      end
      let!(:activity2) do
        Fabricate(:discourse_activity_pub_activity_create, object: note2, actor: actor)
      end

      it "removes the actor's association with the source user" do
        merge_users!
        expect(actor.reload.model_id).to eq(nil)
      end

      it "does not destroy the actor's activities" do
        merge_users!
        expect(DiscourseActivityPubActivity.exists?(activity1.id)).to eq(true)
        expect(DiscourseActivityPubActivity.exists?(activity2.id)).to eq(true)
      end

      it "does not destroy objects of the actor's activities" do
        merge_users!
        expect(DiscourseActivityPubObject.exists?(note1.id)).to eq(true)
        expect(DiscourseActivityPubObject.exists?(note2.id)).to eq(true)
      end
    end

    context "when source user is associated with a local actor" do
      let!(:actor) do
        Fabricate(:discourse_activity_pub_actor_person, model: source_user, local: true)
      end
      let!(:note1) { Fabricate(:discourse_activity_pub_object_note) }
      let!(:note2) { Fabricate(:discourse_activity_pub_object_note) }
      let!(:activity1) do
        Fabricate(:discourse_activity_pub_activity_create, object: note1, actor: actor)
      end
      let!(:activity2) do
        Fabricate(:discourse_activity_pub_activity_create, object: note2, actor: actor)
      end

      it "associates the target user with the actor" do
        merge_users!
        expect(actor.reload.model_id).to eq(target_user.id)
      end

      it "does not destroy the actor's activities" do
        merge_users!
        expect(DiscourseActivityPubActivity.exists?(activity1.id)).to eq(true)
        expect(DiscourseActivityPubActivity.exists?(activity2.id)).to eq(true)
      end

      it "does not destroy objects of the actor's activities" do
        merge_users!
        expect(DiscourseActivityPubObject.exists?(note1.id)).to eq(true)
        expect(DiscourseActivityPubObject.exists?(note2.id)).to eq(true)
      end
    end
  end
end
