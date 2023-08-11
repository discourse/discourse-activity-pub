# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::UserHandler do
  describe "#update_or_create_user" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_person) }

    it "creates a user for actor" do
      user = described_class.update_or_create_user(actor)
      expect(actor.reload.model_id).to eq(user.id)
    end

    context "when user has authorized the same actor id" do
      let!(:user) { Fabricate(:user) }

      before do
        user.activity_pub_save_actor_id("https://external.com", actor.ap_id)
      end

      it "assocates the user with the actor" do
        described_class.update_or_create_user(actor)
        expect(actor.reload.model_id).to eq(user.id)
      end
    end

    context "when actor has user" do
      let(:user) { Fabricate(:user) }

      before do
        actor.update(model_id: user.id, model_type: 'User')
      end

      it "returns the user" do
        user = described_class.update_or_create_user(actor)
        expect(actor.reload.model_id).to eq(user.id)
      end

      it "doesn't create another user" do
        user_count = User.all.size
        described_class.update_or_create_user(actor)
        expect(User.all.size).to eq(user_count)
      end
    end

    context "when actor has icon" do
      before do
        actor.icon_url = "logo.png"
        actor.save
        FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
      end

      it "downloads and sets an icon as user's avatar" do
        user = described_class.update_or_create_user(actor)
        expect(user.user_avatar.custom_upload.origin).to eq("logo.png")
      end

      it "updates user's avatar if icon changes" do
        described_class.update_or_create_user(actor)

        FileHelper.stubs(:download).returns(file_from_fixtures("logo-dev.png"))
        actor.icon_url = "logo-dev.png"
        actor.save
        user = described_class.update_or_create_user(actor)
        expect(user.user_avatar.custom_upload.origin).to eq("logo-dev.png")
      end
    end
  end

  describe "#update_or_create_actor" do
    let!(:user) { Fabricate(:user) }

    it "creates an actor for a user" do
      actor = described_class.update_or_create_actor(user)
      expect(actor.reload.model_id).to eq(user.id)
    end

    context "when user has an actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person) }

      before do
        actor.update(model_id: user.id, model_type: 'User')
      end

      it "returns the actor" do
        actor = described_class.update_or_create_actor(user)
        expect(actor.reload.model_id).to eq(user.id)
      end

      it "doesn't create another actor" do
        actor_count = DiscourseActivityPubActor.all.size
        described_class.update_or_create_actor(user)
        expect(DiscourseActivityPubActor.all.size).to eq(actor_count)
      end
    end
  end
end