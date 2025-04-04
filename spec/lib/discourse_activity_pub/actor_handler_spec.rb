# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ActorHandler do
  describe "#update_or_create_user" do
    let!(:actor) { Fabricate(:discourse_activity_pub_actor_person) }

    it "creates a user for actor" do
      user = described_class.update_or_create_user(actor)
      expect(actor.reload.model_id).to eq(user.id)
    end

    context "when the actor is not a valid type" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_application, model: nil) }

      before { setup_logging }
      after { teardown_logging }

      it "does not create a user" do
        result = described_class.update_or_create_user(actor)
        expect(result).to eq(nil)
      end

      it "logs the right warning" do
        described_class.update_or_create_user(actor)
        expect(@fake_logger.warnings.first).to match(
          I18n.t(
            "discourse_activity_pub.actor.warning.cant_create_model_for_actor_type",
            actor_id: actor.ap_id,
            actor_type: actor.ap_type,
          ),
        )
      end
    end

    context "when the actor is for a category or tag" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

      it "does nothing" do
        result = described_class.update_or_create_user(actor)
        expect(result).to eq(nil)
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
        fab!(:user)

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
            handler = described_class.new(actor: actor)
            handler.skip_avatar_update = false
            handler.update_or_create_user
            expect(user.user_avatar.custom_upload.origin).to eq("#{external_origin}/logo.png")
          end

          it "updates user's avatar if the icon changes" do
            handler = described_class.new(actor: actor)
            handler.skip_avatar_update = false
            handler.update_or_create_user

            FileHelper.stubs(:download).returns(file_from_fixtures("logo-dev.png"))
            actor.icon_url = "#{external_origin}/logo-dev.png"
            actor.save

            handler = described_class.new(actor: actor)
            handler.skip_avatar_update = false
            handler.update_or_create_user
            expect(user.user_avatar.custom_upload.origin).to eq("#{external_origin}/logo-dev.png")
          end
        end
      end

      context "when the actor does not have a user" do
        it "downloads and sets the icon as the user's avatar" do
          handler = described_class.new(actor: actor)
          handler.skip_avatar_update = false
          user = handler.update_or_create_user
          expect(user.user_avatar.custom_upload.origin).to eq("#{external_origin}/logo.png")
        end
      end
    end
  end

  describe "#update_or_create_actor" do
    let!(:category) { Fabricate(:category) }

    context "with a user" do
      let!(:user) { Fabricate(:user) }

      it "creates an actor" do
        actor = described_class.update_or_create_actor(user)
        expect(actor.reload.model_id).to eq(user.id)
      end

      context "with a local actor" do
        let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, model: user, local: true) }

        it "returns the actor" do
          actor = described_class.update_or_create_actor(user)
          expect(actor.reload.model_id).to eq(user.id)
        end

        it "doesn't create another actor" do
          actor_count = DiscourseActivityPubActor.all.size
          described_class.update_or_create_actor(user)
          expect(DiscourseActivityPubActor.all.size).to eq(actor_count)
        end

        context "when required attributes are blank" do
          before { actor.update(public_key: nil, private_key: nil, inbox: nil, outbox: nil) }

          it "ensures they are set" do
            described_class.update_or_create_actor(user)
            expect(actor.reload.ap_key).to be_present
            expect(actor.ap_id).to be_present
            expect(actor.inbox).to eq("#{actor.ap_id}/inbox")
            expect(actor.outbox).to eq("#{actor.ap_id}/outbox")
            expect(actor.keypair).to be_present
          end

          it "ensures inbox and outbox urls have the correct structure" do
            actor.update(inbox: "/inbox", outbox: "/outbox")
            described_class.update_or_create_actor(user)
            expect(actor.inbox).to eq("#{actor.ap_id}/inbox")
            expect(actor.outbox).to eq("#{actor.ap_id}/outbox")
          end
        end
      end

      context "with an invalid ActivityPub username" do
        before do
          SiteSetting.unicode_usernames = true
          user.username = "óengus"
          user.save!
        end

        it "creates a valid ActivityPub username" do
          actor = described_class.update_or_create_actor(user)
          expect(actor.username).to eq("oengus")
        end
      end
    end

    context "with a non-human user" do
      let!(:user) { Discourse.system_user }

      it "creates an actor" do
        actor = described_class.update_or_create_actor(user)
        expect(actor.reload.model_id).to eq(user.id)
      end
    end

    context "with a category" do
      let!(:category) { Fabricate(:category) }

      context "without options" do
        before { setup_logging }
        after { teardown_logging }

        it "does not create an actor" do
          expect { described_class.update_or_create_actor(category) }.not_to change {
            DiscourseActivityPubActor.count
          }
        end

        it "logs the right error" do
          described_class.update_or_create_actor(category)
          expect(@fake_logger.warnings.first).to match(
            I18n.t("discourse_activity_pub.actor.warning.no_options"),
          )
        end
      end

      context "with options" do
        let!(:opts) do
          {
            enabled: true,
            name: "New name",
            default_visibility: "public",
            publication_type: "full_topic",
            post_object_type: DiscourseActivityPub::AP::Object::Article.type,
          }
        end

        context "with an actor" do
          let!(:actor) do
            Fabricate(:discourse_activity_pub_actor_group, model: category, enabled: true)
          end

          it "updates actor fields" do
            actor = described_class.update_or_create_actor(category, opts)
            expect(actor.present?).to eq(true)
            expect(actor.name).to eq(opts[:name])
          end

          it "updates category fields" do
            actor = described_class.update_or_create_actor(category, opts)
            expect(category.activity_pub_enabled).to eq(true)
            expect(category.activity_pub_name).to eq(opts[:name])
            expect(category.activity_pub_default_visibility).to eq(opts[:default_visibility])
            expect(category.activity_pub_publication_type).to eq(opts[:publication_type])
            expect(category.activity_pub_post_object_type).to eq(opts[:post_object_type])
          end

          it "doesn't create another actor" do
            expect { described_class.update_or_create_actor(category, opts) }.not_to change {
              DiscourseActivityPubActor.count
            }
          end

          it "publishes activity pub state" do
            message =
              MessageBus
                .track_publish("/activity-pub") do
                  described_class.update_or_create_actor(category, opts)
                end
                .first
            expect(message.data).to eq(
              { model: { id: category.id, type: "category", ready: true, enabled: true } },
            )
          end

          context "with a changed username" do
            let!(:original_username) { actor.username }

            it "updates the username" do
              opts[:username] = "new_username"
              described_class.update_or_create_actor(category, opts)
              expect(actor.reload.username).to eq("new_username")
              expect(category.reload.activity_pub_username).to eq("new_username")
            end
          end
        end

        context "without an actor" do
          context "with an invalid username" do
            before { setup_logging }
            after { teardown_logging }

            it "does not create an actor" do
              opts[:username] = "óengus"
              expect { described_class.update_or_create_actor(category, opts) }.not_to change {
                DiscourseActivityPubActor.count
              }
            end

            it "logs an error" do
              opts[:username] = "óengus"
              described_class.update_or_create_actor(category, opts)
              expect(@fake_logger.warnings.first).to match(
                I18n.t(
                  "discourse_activity_pub.actor.warning.invalid_username",
                  min_length: SiteSetting.min_username_length,
                  max_length: SiteSetting.max_username_length,
                ),
              )
            end
          end

          context "with a taken username" do
            let!(:existing_actor) { Fabricate(:discourse_activity_pub_actor_group) }

            before { setup_logging }
            after { teardown_logging }

            it "does not create an actor" do
              opts[:username] = existing_actor.username
              expect { described_class.update_or_create_actor(category, opts) }.not_to change {
                DiscourseActivityPubActor.count
              }
            end

            it "logs an error" do
              opts[:username] = existing_actor.username
              described_class.update_or_create_actor(category, opts)
              expect(@fake_logger.warnings.first).to match(
                I18n.t(
                  "discourse_activity_pub.actor.warning.username_taken",
                  model_id: category.id,
                  model_type: category.class.name,
                ),
              )
            end
          end

          context "with a valid username" do
            it "creates an actor" do
              opts[:username] = "valid_username"
              actor = described_class.update_or_create_actor(category, opts)
              expect(actor.reload.model_id).to eq(category.id)
              expect(actor.model_type).to eq("Category")
              expect(actor.name).to eq(opts[:name])
              expect(actor.username).to eq(opts[:username])
            end

            it "updates category fields" do
              opts[:username] = "valid_username"
              actor = described_class.update_or_create_actor(category, opts)
              expect(category.reload.activity_pub_username).to eq(opts[:username])
              expect(category.activity_pub_default_visibility).to eq(opts[:default_visibility])
              expect(category.activity_pub_publication_type).to eq(opts[:publication_type])
              expect(category.activity_pub_post_object_type).to eq(opts[:post_object_type])
            end
          end
        end
      end
    end

    context "with an unsupported model" do
      let!(:topic) { Fabricate(:topic) }

      before { setup_logging }
      after { teardown_logging }

      it "does not create an actor" do
        expect { described_class.update_or_create_actor(topic) }.not_to change {
          DiscourseActivityPubActor.count
        }
      end

      it "logs the right warning" do
        described_class.update_or_create_actor(topic)
        expect(@fake_logger.warnings.first).to match(
          I18n.t(
            "discourse_activity_pub.actor.warning.cant_create_actor_for_model_type",
            model_id: topic.id,
            model_type: topic.class.name,
          ),
        )
      end
    end
  end
end
