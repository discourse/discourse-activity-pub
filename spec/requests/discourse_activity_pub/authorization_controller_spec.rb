# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AuthorizationController do
  let!(:user) { Fabricate(:user) }

  let!(:external_domain1) { "external1.com" }
  let!(:external_domain2) { "external2.com" }
  let!(:external_actor_id) { "https://external1.com/users/user1" }

  let!(:mastodon_client_id) { "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM" }
  let!(:mastodon_client_secret) { "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw" }
  let!(:mastodon_access_token) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }
  let!(:mastodon_code) { "123456" }
  let!(:mastodon_client_access_token) { "BA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }
  let!(:mastodon_app_json) do
    {
      id: "563419",
      name: "test app",
      website: "",
      redirect_uri:
        "#{DiscourseActivityPub.base_url}/#{DiscourseActivityPub::Auth::Mastodon::REDIRECT_PATH}",
      client_id: mastodon_client_id,
      client_secret: mastodon_client_secret,
      vapid_key:
        "BCk-QqERU0q-CfYZjcuB6lnyyOYfJ2AifKqfeGIm7Z-HiTU5T9eTG5GxVA0_OH5mMlI4UkkDTpaZwozy0TzdZ2M=",
    }
  end

  describe "#index" do
    context "when not logged in" do
      it "returns a not authorized response" do
        get "/ap/auth"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      context "without activity pub enabled" do
        before { SiteSetting.activity_pub_enabled = false }

        it "returns a not enabled error" do
          get "/ap/auth"
          expect_not_enabled(response)
        end
      end

      context "with activity pub enabled" do
        before { SiteSetting.activity_pub_enabled = true }

        it "returns authorizations" do
          actor = Fabricate(:discourse_activity_pub_actor_person, model: user)
          mastodon =
            Fabricate(:discourse_activity_pub_authorization_mastodon, user: user, actor: actor)
          get "/ap/auth"
          expect(response.status).to eq(200)
          expect(response.parsed_body["authorizations"].map { |a| a["id"] }).to match_array(
            [mastodon.id],
          )
        end
      end
    end
  end

  describe "#verify" do
    before { sign_in(user) }

    context "without a domain param" do
      it "returns a missing param error" do
        post "/ap/auth/verify"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: domain",
        )
      end
    end

    context "without a auth_type param" do
      it "returns a missing param error" do
        post "/ap/auth/verify", params: { domain: external_domain1 }
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: auth_type",
        )
      end
    end

    context "with mastodon" do
      context "when the domain returns an app" do
        before do
          stub_request(
            :post,
            "https://#{external_domain1}/#{DiscourseActivityPub::Auth::Mastodon::APP_PATH}",
          ).to_return(
            body: mastodon_app_json.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
            status: 200,
          )
        end

        context "when the domain verifies the app" do
          before do
            stub_request(
              :get,
              "https://#{external_domain1}/#{DiscourseActivityPub::Auth::Mastodon::APP_CHECK_PATH}",
            ).to_return(status: 200)
            stub_request(
              :post,
              "https://#{external_domain1}/#{DiscourseActivityPub::Auth::Mastodon::TOKEN_PATH}",
            ).to_return(status: 200, body: { access_token: mastodon_client_access_token }.to_json)
          end

          it "returns the domain" do
            post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "mastodon" }
            expect(response.status).to eq(200)
            expect(response.parsed_body["domain"]).to eq(external_domain1)
          end

          it "sets the domain as the verified domain in the session" do
            post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "mastodon" }
            expect(read_secure_session[described_class::DOMAIN_SESSION_KEY]).to eq(external_domain1)
          end

          it "creates a client" do
            post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "mastodon" }
            client =
              DiscourseActivityPubClient.find_by(
                domain: external_domain1,
                auth_type: DiscourseActivityPubClient.auth_types[:mastodon],
              )
            expect(client.credentials["client_id"]).to eq(mastodon_client_id)
          end
        end
      end

      context "when the domain does not return an app" do
        before do
          stub_request(
            :post,
            "https://#{external_domain2}/#{DiscourseActivityPub::Auth::Mastodon::APP_PATH}",
          ).to_return(status: 400)
          stub_request(
            :get,
            "https://#{external_domain2}/#{DiscourseActivityPub::Auth::Mastodon::APP_CHECK_PATH}",
          ).to_return(status: 400)
        end

        it "returns an error" do
          post "/ap/auth/verify", params: { domain: external_domain2, auth_type: "mastodon" }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_activity_pub.auth.error.failed_to_create_client"),
          )
        end

        it "does not set the domain in the session" do
          post "/ap/auth/verify", params: { domain: external_domain2, auth_type: "mastodon" }
          expect(read_secure_session[described_class::DOMAIN_SESSION_KEY]).to eq(nil)
        end

        it "does not create a client" do
          expect {
            post "/ap/auth/verify", params: { domain: external_domain2, auth_type: "mastodon" }
          }.not_to change { DiscourseActivityPubClient.count }
        end
      end

      context "when the domain does not verify an existing client" do
        let!(:client) do
          Fabricate(:discourse_activity_pub_client_mastodon, domain: external_domain1)
        end

        before do
          stub_request(
            :get,
            "https://#{external_domain1}/#{DiscourseActivityPub::Auth::Mastodon::APP_CHECK_PATH}",
          ).to_return(status: 400)
        end

        it "destroys the client" do
          post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "mastodon" }
          expect(response.status).to eq(422)
          expect(DiscourseActivityPubClient.exists?(client.id)).to eq(false)
        end
      end
    end

    context "with discourse" do
      let!(:auth_redirect) { "#{DiscourseActivityPub.base_url}/ap/auth/redirect/discourse" }

      context "with a successful client registration" do
        before do
          stub_request(
            :head,
            "https://#{external_domain1}/#{DiscourseActivityPub::Auth::Discourse::CLIENT_PATH}?client_id=#{DiscourseActivityPubActor.application.ap_id}",
          )
          stub_request(
            :post,
            "https://#{external_domain1}/#{DiscourseActivityPub::Auth::Discourse::CLIENT_PATH}",
          ).to_return(body: { "success" => "OK" }.to_json, status: 200)
        end

        it "returns the domain" do
          post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "discourse" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["domain"]).to eq(external_domain1)
        end

        it "sets the domain as the verified domain in the session" do
          post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "discourse" }
          expect(read_secure_session[described_class::DOMAIN_SESSION_KEY]).to eq(external_domain1)
        end

        it "creates a client" do
          post "/ap/auth/verify", params: { domain: external_domain1, auth_type: "discourse" }
          client =
            DiscourseActivityPubClient.find_by(
              domain: external_domain1,
              auth_type: DiscourseActivityPubClient.auth_types[:discourse],
            )
          expect(client.credentials.keys).to match_array(%w[public_key private_key])
        end
      end
    end
  end

  describe "#authorize" do
    before { sign_in(user) }

    context "without a verified domain in the session" do
      it "raises an invalid access error" do
        get "/ap/auth/authorize/mastodon"
        expect(response.status).to eq(403)
      end
    end

    context "with a verified domain in the session" do
      before do
        write_secure_session(
          DiscourseActivityPub::AuthorizationController::DOMAIN_SESSION_KEY,
          external_domain1,
        )
      end

      context "with an invalid auth_type" do
        it "raises an invalid parameters error" do
          get "/ap/auth/authorize/nodebb"
          expect(response.status).to eq(400)
        end
      end

      context "with mastodon" do
        context "when domain has an client" do
          let!(:client) do
            Fabricate(:discourse_activity_pub_client_mastodon, domain: external_domain1)
          end

          it "redirects to the authorize url for the app" do
            get "/ap/auth/authorize/mastodon", params: { domain: external_domain1 }
            expect(response).to redirect_to(
              DiscourseActivityPub::Auth::Mastodon.get_authorize_url(external_domain1),
            )
          end
        end

        context "when domain does not have a client" do
          it "does not redirect and returns an error" do
            get "/ap/auth/authorize/mastodon"
            expect(response.status).to eq(400)
          end
        end
      end

      context "with discourse" do
        let!(:client) do
          Fabricate(:discourse_activity_pub_client_discourse, domain: external_domain1)
        end

        it "creates an authorization" do
          get "/ap/auth/authorize/discourse"
          expect(DiscourseActivityPubAuthorization.where(client_id: client.id).exists?).to eq(true)
        end

        it "saves the authorization id to the session" do
          get "/ap/auth/authorize/discourse"
          expect(
            DiscourseActivityPubAuthorization.exists?(
              read_secure_session[described_class::AUTHORIZATION_SESSION_KEY].to_i,
            ),
          ).to eq(true)
        end

        it "saves a nonce to the session" do
          ENV["ACTIVITY_PUB_TEST_RANDOM_HEX"] = "123"
          get "/ap/auth/authorize/discourse"
          expect(read_secure_session[described_class::NONCE_SESSION_KEY]).to eq("123")
        end

        it "redirects to the authorize url for the app" do
          get "/ap/auth/authorize/discourse"
          expect(response).to redirect_to(
            DiscourseActivityPub::Auth::Discourse.get_authorize_url(external_domain1),
          )
        end
      end
    end
  end

  describe "#redirect" do
    before { sign_in(user) }

    context "without an authorization id in the session" do
      it "raises an invalid access error" do
        get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
        expect(response.status).to eq(403)
      end
    end

    context "with an authorization id in the session" do
      let!(:authorization) { Fabricate(:discourse_activity_pub_authorization_mastodon, user: user) }

      before do
        write_secure_session(
          DiscourseActivityPub::AuthorizationController::AUTHORIZATION_SESSION_KEY,
          authorization.id,
        )
      end

      context "with mastodon" do
        context "without a code param" do
          it "redirects to the current user's activity pub settings with the right error" do
            get "/ap/auth/redirect/mastodon"
            message = CGI.escape("Invalid redirect params")
            expect(response).to redirect_to(
              "/u/#{user.username}/preferences/activity-pub?error=#{message}",
            )
          end
        end

        context "with an unsuccessful request for an access token for the domain" do
          before do
            stub_request(
              :post,
              "https://#{authorization.client.domain}/#{DiscourseActivityPub::Auth::Mastodon::TOKEN_PATH}",
            ).to_return(status: 404)
          end

          it "redirects to the current user's activity pub settings with the right error" do
            get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
            message = CGI.escape("Failed to get token")
            expect(response).to redirect_to(
              "/u/#{user.username}/preferences/activity-pub?error=#{message}",
            )
          end
        end

        context "with a successful request for an access token for the domain" do
          before do
            DiscourseActivityPub::Auth::Mastodon
              .any_instance
              .stubs(:get_token)
              .with({ code: mastodon_code })
              .returns(mastodon_access_token)
          end

          context "with an successful request for an actor id with the access token" do
            let!(:actor) do
              Fabricate(:discourse_activity_pub_actor_person, ap_id: external_actor_id)
            end

            before do
              DiscourseActivityPub::Auth::Mastodon
                .any_instance
                .stubs(:get_actor_ap_id)
                .with(mastodon_access_token)
                .returns(external_actor_id)
            end

            it "adds the token to the authorization" do
              get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
              expect(authorization.reload.token).to eq(mastodon_access_token)
            end

            it "adds the actor to the authorization" do
              get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
              expect(authorization.reload.actor.ap_id).to eq(external_actor_id)
            end

            context "with a staged user with an actor with the returned actor id" do
              let!(:user2) { Fabricate(:user, staged: true) }
              before do
                actor.model = user2
                actor.save!
              end

              it "enqueues a job to merge the existing user into the current user" do
                get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
                args = { user_id: user2.id, target_user_id: user.id, current_user_id: user.id }
                expect(job_enqueued?(job: :merge_user, args: args)).to eq(true)
              end
            end

            it "redirects to the current user's activity pub settings" do
              get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
              expect(response).to redirect_to("/u/#{user.username}/preferences/activity-pub")
            end
          end

          context "with an unsuccessful request for an actor id with the access token" do
            before do
              DiscourseActivityPub::Auth::Mastodon
                .any_instance
                .stubs(:get_account)
                .with(mastodon_access_token)
                .returns(nil)
            end

            it "redirects to the current user's activity pub settings with the right error" do
              get "/ap/auth/redirect/mastodon", params: { code: mastodon_code }
              message = CGI.escape("Failed to get actor")
              expect(response).to redirect_to(
                "/u/#{user.username}/preferences/activity-pub?error=#{message}",
              )
            end
          end
        end
      end

      context "with discourse" do
        context "with an authorization in the session" do
          let!(:authorization) do
            Fabricate(:discourse_activity_pub_authorization_discourse, user: user)
          end

          before do
            write_secure_session(
              DiscourseActivityPub::AuthorizationController::AUTHORIZATION_SESSION_KEY,
              authorization.id,
            )
          end

          context "with a nonce in the session" do
            let!(:nonce) { "12345" }

            before do
              write_secure_session(
                DiscourseActivityPub::AuthorizationController::NONCE_SESSION_KEY,
                nonce,
              )
            end

            context "when the callback has a valid payload" do
              let!(:key) { "12345" }
              let!(:actor_json) { build_actor_json }
              let!(:raw_payload) { { key: key, nonce: nonce, push: false, api: 4 } }
              let!(:payload) do
                rsa = OpenSSL::PKey::RSA.new(authorization.client.credentials["private_key"])
                Base64.encode64(rsa.public_encrypt(raw_payload.to_json))
              end

              before do
                stub_request(
                  :get,
                  "https://#{authorization.client.domain}/#{DiscourseActivityPub::Auth::Discourse::FIND_ACTOR_BY_USER_PATH}",
                ).with(headers: { "User-Api-Key" => key }).to_return(
                  body: actor_json.to_json,
                  headers: {
                    "Content-Type" => "application/json",
                  },
                  status: 200,
                )
                stub_request(:get, actor_json[:id]).to_return(
                  body: actor_json.to_json,
                  headers: {
                    "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
                  },
                  status: 200,
                )
              end

              it "adds the token to the authorization" do
                get "/ap/auth/redirect/discourse", params: { payload: payload }
                expect(authorization.reload.token).to eq(key)
              end

              it "adds the actor to the authorization" do
                get "/ap/auth/redirect/discourse", params: { payload: payload }
                expect(authorization.reload.actor.ap_id).to eq(actor_json[:id])
              end

              context "with a staged user with an actor with the returned actor id" do
                let!(:user2) { Fabricate(:user, staged: true) }
                let!(:actor) do
                  Fabricate(
                    :discourse_activity_pub_actor_person,
                    ap_id: actor_json[:id],
                    model: user2,
                  )
                end

                it "enqueues a job to merge the existing user into the current user" do
                  get "/ap/auth/redirect/discourse", params: { payload: payload }
                  args = { user_id: user2.id, target_user_id: user.id, current_user_id: user.id }
                  expect(job_enqueued?(job: :merge_user, args: args)).to eq(true)
                end
              end

              it "redirects to the current user's activity pub settings" do
                get "/ap/auth/redirect/discourse", params: { payload: payload }
                expect(response).to redirect_to("/u/#{user.username}/preferences/activity-pub")
              end
            end
          end
        end
      end
    end
  end

  describe "#destroy" do
    before { sign_in(user) }

    context "with a valid authorization id" do
      let!(:authorization) { Fabricate(:discourse_activity_pub_authorization_mastodon) }

      it "destroys the authorization" do
        delete "/ap/auth/destroy/#{authorization.id}"
        expect(response).to be_successful
        expect(DiscourseActivityPubAuthorization.find_by(id: authorization.id)).to eq(nil)
      end
    end

    context "without a valid authorization id" do
      it "is not successful" do
        delete "/ap/auth/destroy/2"
        expect(response).not_to be_successful
      end
    end
  end
end
