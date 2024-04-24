# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::AuthorizationController do
  let!(:user) { Fabricate(:user) }
  let!(:domain1) { "external1.com" }
  let!(:domain2) { "external2.com" }
  let!(:redirect_uri) do
    "#{DiscourseActivityPub.base_url}/#{DiscourseActivityPub::Auth::Mastodon::REDIRECT_PATH}"
  end
  let!(:client_id) { "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM" }
  let!(:client_secret) { "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw" }
  let!(:access_token1) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }
  let!(:code) { "123456" }
  let!(:mastodon_app_json) do
    {
      id: "563419",
      name: "test app",
      website: "",
      redirect_uri: redirect_uri,
      client_id: client_id,
      client_secret: client_secret,
      vapid_key:
        "BCk-QqERU0q-CfYZjcuB6lnyyOYfJ2AifKqfeGIm7Z-HiTU5T9eTG5GxVA0_OH5mMlI4UkkDTpaZwozy0TzdZ2M=",
    }
  end
  let!(:discourse_app_json) { { client_id: client_id, pem: OpenSSL::PKey::RSA.new(2048).export } }
  let(:actor_id) { "https://external1.com/users/user1" }

  before { sign_in(user) }

  it { expect(described_class).to be < DiscourseActivityPub::AuthController }

  def setup_mastodon_app
    DiscourseActivityPub::Auth::Mastodon.save_app(domain1, mastodon_app_json)
  end

  def remove_mastodon_app
    DiscourseActivityPub::Auth::Mastodon.any_instance.stubs(:create_app).returns(false)
    DiscourseActivityPub::Auth::Mastodon.any_instance.stubs(:get_app).returns(nil)
  end

  def setup_discourse_app
    DiscourseActivityPub::Auth::Discourse.save_app(domain1, discourse_app_json)
  end

  def remove_discourse_app
    DiscourseActivityPub::Auth::Discourse.any_instance.stubs(:create_app).returns(false)
    DiscourseActivityPub::Auth::Discourse.any_instance.stubs(:get_app).returns(nil)
  end

  describe "#verify" do
    context "without a domain param" do
      it "returns a missing param error" do
        post "/ap/auth/verify"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: domain",
        )
      end
    end

    context "without a platform param" do
      it "returns a missing param error" do
        post "/ap/auth/verify", params: { domain: domain1 }
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: platform",
        )
      end
    end

    context "with a domain param" do
      context "with mastodon" do
        context "when the domain returns an app" do
          before do
            stub_request(
              :post,
              "https://#{domain1}/#{DiscourseActivityPub::Auth::Mastodon::APP_PATH}",
            ).to_return(
              body: mastodon_app_json.to_json,
              headers: {
                "Content-Type" => "application/json",
              },
              status: 200,
            )
          end

          it "creates an app and returns the domain" do
            post "/ap/auth/verify", params: { domain: domain1, platform: "mastodon" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["domain"]).to eq(domain1)
            app = DiscourseActivityPub::Auth::Mastodon.get_app(domain1)
            expect(app.client_id).to eq(mastodon_app_json[:client_id])
          end

          it "sets the domain as the verified domain in the session" do
            post "/ap/auth/verify", params: { domain: domain1, platform: "mastodon" }
            expect(
              read_secure_session[
                DiscourseActivityPub::Auth::AuthorizationController::AUTHORIZE_DOMAIN_KEY
              ],
            ).to eq(domain1)
          end
        end

        context "when the domain does not have an app" do
          before { remove_mastodon_app }

          it "returns an error" do
            post "/ap/auth/verify", params: { domain: domain2, platform: "mastodon" }
            expect(response.status).to eq(422)
            expect(response.parsed_body["errors"].first).to eq(
              I18n.t("discourse_activity_pub.auth.error.failed_to_create_app"),
            )
          end

          it "does not set the domain in the session" do
            post "/ap/auth/verify", params: { domain: domain2, platform: "mastodon" }
            expect(
              read_secure_session[
                DiscourseActivityPub::Auth::AuthorizationController::AUTHORIZE_DOMAIN_KEY
              ],
            ).to eq(nil)
          end
        end
      end

      context "with discourse" do
        let!(:auth_redirect) { "#{DiscourseActivityPub.base_url}/ap/auth/redirect/discourse" }
        let!(:verify_redirect_url) do
          "https://#{domain1}/ap/auth/verify-redirect?auth_redirect=#{auth_redirect}"
        end

        context "with an unverified redirect" do
          before { stub_request(:post, verify_redirect_url).to_return(status: 403) }

          it "returns the right error" do
            post "/ap/auth/verify", params: { domain: domain1, platform: "discourse" }
            expect(response.status).to eq(422)
            expect(response.parsed_body["errors"].first).to eq(
              I18n.t("discourse_activity_pub.auth.error.failed_to_verify_redirect"),
            )
          end
        end

        context "with an verified redirect" do
          before do
            stub_request(:post, verify_redirect_url).to_return(status: 200)
            setup_mastodon_app
          end

          it "returns the domain" do
            post "/ap/auth/verify", params: { domain: domain1, platform: "discourse" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["domain"]).to eq(domain1)
          end

          it "sets the domain as the verified domain in the session" do
            post "/ap/auth/verify", params: { domain: domain1, platform: "discourse" }
            expect(
              read_secure_session[
                DiscourseActivityPub::Auth::AuthorizationController::AUTHORIZE_DOMAIN_KEY
              ],
            ).to eq(domain1)
          end
        end
      end
    end
  end

  describe "verify_redirect" do
    it "verifies a valid auth redirect" do
      SiteSetting.allowed_user_api_auth_redirects = "https://safe.site/redirect"
      get "/ap/auth/verify-redirect", params: { auth_redirect: "https://safe.site/redirect" }
      expect(response.status).to eq(200)
    end

    it "does not verify an invalid auth redirect" do
      SiteSetting.allowed_user_api_auth_redirects = "https://safe.site/redirect"
      get "/ap/auth/verify-redirect", params: { auth_redirect: "https://unsafe.site/redirect" }
      expect(response.status).to eq(403)
    end
  end

  describe "#authorize" do
    context "without a verified domain in the session" do
      it "raises an invalid access error" do
        get "/ap/auth/authorize/mastodon"
        expect(response.status).to eq(403)
      end
    end

    context "with a verified domain in the session" do
      before do
        write_secure_session(
          DiscourseActivityPub::Auth::AuthorizationController::AUTHORIZE_DOMAIN_KEY,
          domain1,
        )
      end

      context "with an invalid platform" do
        it "raises an invalid parameters error" do
          get "/ap/auth/authorize/nodebb"
          expect(response.status).to eq(400)
        end
      end

      context "with mastodon" do
        context "when domain has an app" do
          before { setup_mastodon_app }

          it "redirects to the authorize url for the app" do
            get "/ap/auth/authorize/mastodon", params: { domain: domain1 }
            expect(response).to redirect_to(
              DiscourseActivityPub::Auth::Mastodon.get_authorize_url(domain1),
            )
          end
        end

        context "when domain does not have an app" do
          before { remove_mastodon_app }

          it "does not redirect and returns an error" do
            get "/ap/auth/authorize/mastodon"
            expect(response.status).to eq(404)
            expect(response.parsed_body["errors"].first).to eq(
              I18n.t("discourse_activity_pub.auth.error.invalid_domain"),
            )
          end
        end
      end

      context "with discourse" do
        context "when domain has an app" do
          before { setup_discourse_app }

          it "saves a nonce to the app" do
            get "/ap/auth/authorize/discourse"
            app = DiscourseActivityPub::Auth::Discourse.get_app(domain1)
            expect(app.nonce.present?).to eq(true)
          end

          it "redirects to the authorize url for the app" do
            get "/ap/auth/authorize/discourse"
            expect(response).to redirect_to(
              DiscourseActivityPub::Auth::Discourse.get_authorize_url(domain1),
            )
          end
        end

        context "when domain does not have an app" do
          before { DiscourseActivityPub::Auth::Discourse.any_instance.stubs(:get_app).returns(nil) }

          it "does not redirect and returns an error" do
            get "/ap/auth/authorize/discourse"
            expect(response.status).to eq(404)
            expect(response.parsed_body["errors"].first).to eq(
              I18n.t("discourse_activity_pub.auth.error.invalid_domain"),
            )
          end
        end
      end
    end
  end

  describe "#redirect" do
    context "without an verified domain in the session" do
      it "raises an invalid access error" do
        get "/ap/auth/redirect/mastodon", params: { code: code }
        expect(response.status).to eq(403)
      end
    end

    context "with an verified domain in the session" do
      before do
        write_secure_session(
          DiscourseActivityPub::Auth::AuthorizationController::AUTHORIZE_DOMAIN_KEY,
          domain1,
        )
      end

      context "with mastodon" do
        context "without a code param" do
          it "returns an authorization failure" do
            get "/ap/auth/redirect/mastodon"
            expect(response.status).to eq(403)
          end
        end

        context "with an unsuccessful request for an access token for the domain" do
          before do
            DiscourseActivityPub::Auth::Mastodon.stubs(:get_token).with(domain1, code).returns(nil)
          end

          it "raises and invalid access error" do
            get "/ap/auth/redirect/mastodon", params: { code: code }
            expect(response.status).to eq(403)
          end
        end

        context "with a successful request for an access token for the domain" do
          before do
            DiscourseActivityPub::Auth::Mastodon
              .any_instance
              .stubs(:get_token)
              .with({ code: code })
              .returns(access_token1)
          end

          context "when domain has an app" do
            before { setup_mastodon_app }

            it "saves the access token in the current user's custom fields" do
              get "/ap/auth/redirect/mastodon", params: { code: code }
              expect(user.activity_pub_access_tokens[domain1]).to eq(access_token1)
            end

            context "with an successful request for an actor id with the access token" do
              before do
                DiscourseActivityPub::Auth::Mastodon
                  .any_instance
                  .stubs(:get_actor_id)
                  .with(access_token1)
                  .returns(actor_id)
              end

              it "saves the actor id in the current user's custom fields" do
                get "/ap/auth/redirect/mastodon", params: { code: code }
                expect(user.reload.activity_pub_actor_ids[actor_id]).to eq(domain1)
              end

              context "with an existing user with an actor with the returned actor id" do
                let!(:user2) { Fabricate(:user) }
                let!(:actor) do
                  Fabricate(:discourse_activity_pub_actor_person, ap_id: actor_id, model: user2)
                end

                it "enqueues a job to merge the existing user into the current user" do
                  get "/ap/auth/redirect/mastodon", params: { code: code }
                  args = { user_id: user2.id, target_user_id: user.id, current_user_id: user.id }
                  expect(job_enqueued?(job: :merge_user, args: args)).to eq(true)
                end
              end

              it "redirects to the current user's activity pub settings" do
                get "/ap/auth/redirect/mastodon", params: { code: code }
                expect(response).to redirect_to("/u/#{user.username}/preferences/activity-pub")
              end
            end

            context "with an unsuccessful request for an actor id with the access token" do
              before do
                DiscourseActivityPub::Auth::Mastodon
                  .any_instance
                  .stubs(:get_actor_id)
                  .with(access_token1)
                  .returns(nil)
              end

              it "raises a not found error" do
                get "/ap/auth/redirect/mastodon", params: { code: code }
                expect(response.status).to eq(404)
              end
            end
          end
        end
      end

      context "with discourse" do
        context "when domain has an app" do
          before { setup_discourse_app }

          context "when the callback has a valid payload" do
            let!(:key) { "12345" }
            let!(:actor_json) { build_actor_json }

            def raw_auth_payload(app)
              { key: key, nonce: app.nonce, push: false, api: 4 }
            end

            def generate_payload(app)
              public_key = OpenSSL::PKey::RSA.new(app.pem)
              Base64.encode64(public_key.public_encrypt(raw_auth_payload(app).to_json))
            end

            before do
              stub_request(
                :get,
                "https://#{domain1}/#{DiscourseActivityPub::Auth::Discourse::ACTOR_BY_USER_API_KEY_PATH}",
              ).with(headers: { "Authorization" => "Bearer #{key}" }).to_return(
                body: actor_json.to_json,
                headers: {
                  "Content-Type" => "application/json",
                },
                status: 200,
              )
            end

            it "saves the access token in the current user's custom fields" do
              app = DiscourseActivityPub::Auth::Discourse.get_app(domain1)
              get "/ap/auth/redirect/discourse", params: { payload: generate_payload(app) }
              expect(user.activity_pub_access_tokens[domain1]).to eq(key)
            end

            it "saves the actor id in the current user's custom fields" do
              app = DiscourseActivityPub::Auth::Discourse.get_app(domain1)
              get "/ap/auth/redirect/discourse", params: { payload: generate_payload(app) }
              expect(user.reload.activity_pub_actor_ids[actor_json[:id]]).to eq(domain1)
            end

            context "with an existing user with an actor with the returned actor id" do
              let!(:user2) { Fabricate(:user) }
              let!(:actor) do
                Fabricate(
                  :discourse_activity_pub_actor_person,
                  ap_id: actor_json[:id],
                  model: user2,
                )
              end

              it "enqueues a job to merge the existing user into the current user" do
                app = DiscourseActivityPub::Auth::Discourse.get_app(domain1)
                get "/ap/auth/redirect/discourse", params: { payload: generate_payload(app) }
                args = { user_id: user2.id, target_user_id: user.id, current_user_id: user.id }
                expect(job_enqueued?(job: :merge_user, args: args)).to eq(true)
              end
            end

            it "redirects to the current user's activity pub settings" do
              app = DiscourseActivityPub::Auth::Discourse.get_app(domain1)
              get "/ap/auth/redirect/discourse", params: { payload: generate_payload(app) }
              expect(response).to redirect_to("/u/#{user.username}/preferences/activity-pub")
            end
          end
        end
      end
    end
  end

  describe "#destroy" do
    context "with an actor id" do
      let!(:domain) { "https://external1.com" }
      let!(:actor_id) { "https://external1.com/users/user1" }

      context "when the user has authorized the actor" do
        before { user.activity_pub_save_actor_id(domain, actor_id) }

        it "removes the actor id" do
          delete "/ap/auth/destroy", params: { actor_id: actor_id }
          expect(user.reload.activity_pub_actor_ids[actor_id]).to eq(nil)
        end

        it "is successful" do
          delete "/ap/auth/destroy", params: { actor_id: actor_id }
          expect(response).to be_successful
        end
      end

      context "when user has not authorized the actor" do
        it "is not successful" do
          delete "/ap/auth/destroy", params: { actor_id: actor_id }
          expect(response).not_to be_successful
        end
      end
    end
  end
end
