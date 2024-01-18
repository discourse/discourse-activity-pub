# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::UserHandler do
  describe "#update_or_create_user" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_person) }

    it "creates a user for actor" do
      user = described_class.update_or_create_user(actor)
      expect(actor.reload.model_id).to eq(user.id)
    end

    context "when the actor is not a valid type" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: nil) }

      before { setup_logging }
      after { teardown_logging }

      it "does not create a user" do
        user = described_class.update_or_create_user(actor)
        expect(user).to eq(nil)
        expect(actor.reload.model_id).to eq(nil)
      end

      it "logs the right warning" do
        described_class.update_or_create_user(actor)
        expect(@fake_logger.warnings.first).to match(
          I18n.t(
            "discourse_activity_pub.user.warning.cant_create_user_for_actor",
            actor_id: actor.ap_id,
          ),
        )
      end
    end

    context "when user has authorized the same actor id" do
      let!(:user) { Fabricate(:user) }

      before { user.activity_pub_save_actor_id("https://external.com", actor.ap_id) }

      it "associates the user with the actor" do
        described_class.update_or_create_user(actor)
        expect(actor.reload.model_id).to eq(user.id)
      end
    end

    context "when actor has user" do
      let!(:user) { Fabricate(:user) }

      before { actor.update(model_id: user.id, model_type: "User") }

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
      fab!(:external_origin) { "https://external.com" }

      before do
        actor.icon_url = "#{external_origin}/logo.png"
        actor.save
        FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
      end

      context "when the actor has a user" do
        fab!(:user) { Fabricate(:user) }

        before { actor.update(model_id: user.id, model_type: "User") }

        context "when the user has a custom avatar" do
          fab!(:custom_avatar_url) { "/images/avatar.png" }
          fab!(:custom_avatar) { Fabricate(:upload, url: custom_avatar_url, user_id: user.id) }

          before do
            user.user_avatar.update(custom_upload_id: custom_avatar.id)
            user.update(uploaded_avatar_id: custom_avatar.id)
          end

          it "does not set the icon as the user's avatar" do
            described_class.update_or_create_user(actor)
            expect(user.user_avatar.custom_upload.url).to eq(custom_avatar_url)
          end

          it "does not update the user's avatar if the icon changes" do
            described_class.update_or_create_user(actor)
            expect(user.user_avatar.custom_upload.url).to eq(custom_avatar_url)

            FileHelper.stubs(:download).returns(file_from_fixtures("logo-dev.png"))
            actor.icon_url = "#{external_origin}/logo-dev.png"
            actor.save
            described_class.update_or_create_user(actor)
            expect(user.user_avatar.custom_upload.url).to eq(custom_avatar_url)
          end
        end

        context "when the user has a gravatar" do
          fab!(:gravatar_url) { "/images/gravatar.png" }
          fab!(:gravatar) { Fabricate(:upload, url: gravatar_url, user: user) }

          before do
            user.user_avatar.update(gravatar_upload_id: gravatar.id)
            user.update(uploaded_avatar_id: gravatar.id)
          end

          it "does not set the icon as the user's avatar" do
            described_class.update_or_create_user(actor)
            expect(user.uploaded_avatar.id).to eq(gravatar.id)
          end

          it "does not update the user's avatar if the icon changes" do
            described_class.update_or_create_user(actor)
            expect(user.uploaded_avatar.id).to eq(gravatar.id)

            FileHelper.stubs(:download).returns(file_from_fixtures("logo-dev.png"))
            actor.icon_url = "#{external_origin}/logo-dev.png"
            actor.save
            described_class.update_or_create_user(actor)
            expect(user.uploaded_avatar.id).to eq(gravatar.id)
          end
        end

        context "when the user does not have a custom avatar" do
          it "downloads and sets the icon as the user's avatar" do
            described_class.update_or_create_user(actor)
            expect(user.user_avatar.custom_upload.origin).to eq("#{external_origin}/logo.png")
          end

          it "updates user's avatar if the icon changes" do
            described_class.update_or_create_user(actor)

            FileHelper.stubs(:download).returns(file_from_fixtures("logo-dev.png"))
            actor.icon_url = "#{external_origin}/logo-dev.png"
            actor.save
            described_class.update_or_create_user(actor)
            expect(user.user_avatar.custom_upload.origin).to eq("#{external_origin}/logo-dev.png")
          end
        end
      end

      context "when the actor does not have a user" do
        it "downloads and sets the icon as the user's avatar" do
          user = described_class.update_or_create_user(actor)
          expect(user.user_avatar.custom_upload.origin).to eq("#{external_origin}/logo.png")
        end
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

      before { actor.update(model_id: user.id, model_type: "User") }

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
