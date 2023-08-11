# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::OAuthController do
  let!(:user) { Fabricate(:user) }
  let!(:domain1) { "https://external1.com" }
  let!(:domain2) { "https://external2.com" }
  let!(:redirect_uri) { "#{Discourse.base_url}/#{DiscourseActivityPub::Auth::OAuth::REDIRECT_PATH}" }
  let!(:client_id) { "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM" }
  let!(:client_secret) { "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw" }
  let!(:access_token1) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }
  let!(:code) { "123456" }
  let!(:app_json) {
    {
      "id": "563419",
      "name": "test app",
      "website": "",
      "redirect_uri": redirect_uri,
      "client_id": client_id,
      "client_secret": client_secret,
      "vapid_key": "BCk-QqERU0q-CfYZjcuB6lnyyOYfJ2AifKqfeGIm7Z-HiTU5T9eTG5GxVA0_OH5mMlI4UkkDTpaZwozy0TzdZ2M="
    }
  }
  let(:actor_id) { "https://external1.com/users/user1" }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.oauth.error.#{key}")] }
  end

  before do
    sign_in(user)
    user.activity_pub_save_access_token(domain1, access_token1)
    user.activity_pub_save_access_token(domain2, nil)
  end

  it { expect(described_class).to be < DiscourseActivityPub::AuthController }

  describe "#create" do
    context "without a domain param" do
      it "returns a missing param error" do
        post "/ap/auth/oauth"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: domain",
        )
      end
    end

    context "with a domain param" do
      context "with a valid domain" do
        before do
          app = DiscourseActivityPub::Auth::OAuth::App.new(domain1, app_json)
          DiscourseActivityPub::Auth::OAuth.any_instance.stubs(:create_app).returns(app)
        end

        it "creates an app and returns the domain" do
          post "/ap/auth/oauth", params: { domain: domain1 }
          expect(response.status).to eq(200)
          expect(response.parsed_body['domain']).to eq(domain1)
        end
      end

      context "with an invalid domain" do
        before do
          oauth = DiscourseActivityPub::Auth::OAuth.new(domain2)
          oauth.add_error("Not a valid domain")
          DiscourseActivityPub::Auth::OAuth.stubs(:new).with(domain2).returns(oauth)
          DiscourseActivityPub::Auth::OAuth.any_instance.stubs(:create_app).returns(nil)
        end

        it "does not create an app and returns the error" do
          post "/ap/auth/oauth", params: { domain: domain2 }
          expect(response.status).to eq(422)
          expect(response.parsed_body['errors'].first).to eq("Not a valid domain")
        end
      end
    end
  end

  describe "#authorize" do
    context "without a domain param" do
      it "returns a missing param error" do
        get "/ap/auth/authorize"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: domain",
        )
      end
    end

    context "with a domain param" do
      context "when domain has an app" do
        before do
          app = DiscourseActivityPub::Auth::OAuth::App.new(domain1, app_json)
          DiscourseActivityPub::Auth::OAuth.any_instance.stubs(:get_app).returns(app)
        end

        it "sets the domain as the authorize domain in the session" do
          get "/ap/auth/authorize", params: { domain: domain1 }
          expect(
            read_secure_session[DiscourseActivityPub::Auth::OAuthController::AUTHORIZE_DOMAIN_KEY]
          ).to eq(domain1)
        end

        it "redirects to the authorize url for the app" do
          get "/ap/auth/authorize", params: { domain: domain1 }
          expect(response).to redirect_to(
            DiscourseActivityPub::Auth::OAuth.get_authorize_url(domain1)
          )
        end
      end

      context "when domain does not have an app" do
        before do
          DiscourseActivityPub::Auth::OAuth.any_instance.stubs(:get_app).returns(nil)
        end

        it "does not redirect and returns an error" do
          get "/ap/auth/authorize", params: { domain: domain1 }
          expect(response.status).to eq(404)
          expect(response.parsed_body['errors'].first).to eq(
            I18n.t("discourse_activity_pub.auth.error.invalid_oauth_domain")
          )
        end
      end
    end
  end

  describe "#redirect" do
    context "without a code param" do
      it "returns a missing param error" do
        get "/ap/auth/oauth/redirect"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          "param is missing or the value is empty: code",
        )
      end
    end

    context "without an authorize domain in the session" do
      it "raises an invalid access error" do
        get "/ap/auth/oauth/redirect", params: { code: code }
        expect(response.status).to eq(403)
      end
    end

    context "with an authorize domain in the session" do
      before do
        write_secure_session(
          DiscourseActivityPub::Auth::OAuthController::AUTHORIZE_DOMAIN_KEY,
          domain1
        )
      end

      context "with an unsuccessful request for an access token for the domain" do
        before do
          DiscourseActivityPub::Auth::OAuth
            .stubs(:get_token)
            .with(domain1, code)
            .returns(nil)
        end

        it "raises and invalid access error" do
          get "/ap/auth/oauth/redirect", params: { code: code }
          expect(response.status).to eq(403)
        end
      end

      context "with a successful request for an access token for the domain" do
        before do
          DiscourseActivityPub::Auth::OAuth
            .stubs(:get_token)
            .with(domain1, code)
            .returns(access_token1)
        end

        it "saves the access token in the current user's custom fields" do
          get "/ap/auth/oauth/redirect", params: { code: code }
          expect(user.activity_pub_access_tokens[domain1]).to eq(access_token1)
        end

        context "with an successful request for an actor id with the access token" do
          before do
            DiscourseActivityPub::Auth::OAuth
              .stubs(:get_actor_id)
              .with(domain1, access_token1)
              .returns(actor_id)
          end

          it "saves the actor id in the current user's custom fields" do
            get "/ap/auth/oauth/redirect", params: { code: code }
            expect(user.reload.activity_pub_actor_ids[actor_id]).to eq(domain1)
          end

          context "with an existing user with an actor with the returned actor id" do
            let!(:user2) { Fabricate(:user) }
            let!(:actor) { Fabricate(:discourse_activity_pub_actor_person, ap_id: actor_id, model: user2) }

            it "enqueues a job to merge the existing user into the current user" do
              get "/ap/auth/oauth/redirect", params: { code: code }
              args = {
                user_id: user2.id,
                target_user_id: user.id,
                current_user_id: user.id,
              }
              expect(job_enqueued?(job: :merge_user, args: args)).to eq(true)
            end
          end

          it "redirects to the current user's activity pub settings" do
            get "/ap/auth/oauth/redirect", params: { code: code }
            expect(response).to redirect_to("/u/#{user.username}/activity-pub")
          end
        end

        context "with an unsuccessful request for an actor id with the access token" do
          before do
            DiscourseActivityPub::Auth::OAuth
              .stubs(:get_actor_id)
              .with(domain1, access_token1)
              .returns(nil)
          end

          it "raises and a not found error" do
            get "/ap/auth/oauth/redirect", params: { code: code }
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end
end