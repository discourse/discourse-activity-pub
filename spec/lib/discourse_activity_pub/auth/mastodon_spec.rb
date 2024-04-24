# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::Mastodon do
  let!(:domain1) { "external.com" }
  let!(:redirect_uri) do
    "#{DiscourseActivityPub.base_url}/#{DiscourseActivityPub::Auth::Mastodon::REDIRECT_PATH}"
  end
  let!(:client_id) { "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM" }
  let!(:client_secret) { "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw" }
  let!(:code) { "qDFUEaYrRK5c-HNmTCJbAzazwLRInJ7VHFat0wcMgCU" }
  let!(:access_token) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }
  # https://docs.joinmastodon.org/methods/apps/#form-data-parameters
  let!(:app_request_body) do
    {
      client_name: DiscourseActivityPub.host,
      redirect_uris: redirect_uri,
      scopes: DiscourseActivityPub::Auth::Mastodon::SCOPES,
      website: DiscourseActivityPub.base_url,
    }
  end
  # https://docs.joinmastodon.org/methods/apps/#200-ok
  let!(:app_response_body) do
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
  let!(:app_stored) do
    { client_id: app_response_body[:client_id], client_secret: app_response_body[:client_secret] }
  end
  # https://docs.joinmastodon.org/methods/apps/#422-unprocessable-entity
  let!(:app_error_body) { { error: "Validation failed: Redirect URI must be an absolute URI." } }
  # https://docs.joinmastodon.org/methods/Mastodon/#form-data-parameters
  let!(:token_request_body) do
    {
      grant_type: "authorization_code",
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      scope: DiscourseActivityPub::Auth::Mastodon::SCOPES,
    }
  end
  # https://docs.joinmastodon.org/methods/Mastodon/#200-ok-1
  let!(:token_response_body) do
    {
      access_token: access_token,
      token_type: "Bearer",
      scope: DiscourseActivityPub::Auth::Mastodon::SCOPES,
      created_at: 1_573_979_017,
    }
  end
  # https://docs.joinmastodon.org/methods/Mastodon/#401-unauthorized
  let!(:token_error_body) do
    {
      error: "invalid_client",
      error_description:
        "Client authentication failed due to unknown client, no client authentication included, or unsupported authentication method.",
    }
  end
  # https://docs.joinmastodon.org/methods/accounts/#200-ok-1
  let!(:account_response_body) do
    {
      id: "14715",
      username: "angus",
      acct: "angus",
      display_name: "Angus McLeod",
      url: "https://mastodon.social/@angus",
    }
  end
  # https://docs.joinmastodon.org/methods/accounts/#401-unauthorized-1
  let!(:account_error_body) { { error: "The access token is invalid" } }

  def build_response(body: {}, status: 200)
    Excon::Response.new(body: body.to_json, status: status)
  end

  def expect_request(domain: "", path: "", body: nil, verb: :post, response: nil, headers: nil)
    opts = {}
    opts[:body] = body.to_json if body
    opts[:headers] = {}
    opts[:headers]["Content-Type"] = "application/json" if body
    headers.each { |k, v| opts[:headers][k] = v } if headers

    Excon.expects(:send).with(verb, "https://#{domain}/#{path}", opts).returns(response)
  end

  describe "create_app" do
    it "sends the right request to create an app" do
      expect_request(
        domain: domain1,
        path: DiscourseActivityPub::Auth::Mastodon::APP_PATH,
        body: app_request_body,
      )
      DiscourseActivityPub::Auth::Mastodon.create_app(domain1)
    end

    context "with a successful response" do
      before do
        expect_request(
          domain: domain1,
          path: DiscourseActivityPub::Auth::Mastodon::APP_PATH,
          body: app_request_body,
          response: build_response(body: app_response_body, status: 200),
        )
      end

      it "saves the response" do
        DiscourseActivityPub::Auth::Mastodon.create_app(domain1)
        expect(
          PluginStoreRow.exists?(
            plugin_name: DiscourseActivityPub::Auth::Mastodon.plugin_store_key,
            key: domain1,
            value: app_stored.to_json,
          ),
        ).to eq(true)
      end

      it "returns a modelled app" do
        app = DiscourseActivityPub::Auth::Mastodon.create_app(domain1)
        expect(app&.domain).to eq(domain1)
        expect(app.client_id).to eq(client_id)
        expect(app.client_secret).to eq(client_secret)
      end
    end

    context "with an error response" do
      before do
        expect_request(
          domain: domain1,
          path: DiscourseActivityPub::Auth::Mastodon::APP_PATH,
          body: app_request_body,
          response: build_response(body: app_error_body, status: 422),
        )
      end

      it "does not save the response" do
        DiscourseActivityPub::Auth::Mastodon.create_app(domain1)
        expect(
          PluginStoreRow.exists?(plugin_name: DiscourseActivityPub::PLUGIN_NAME, key: domain1),
        ).to eq(false)
      end

      it "returns nil" do
        expect(DiscourseActivityPub::Auth::Mastodon.create_app(domain1)).to eq(nil)
      end

      it "adds returned errors to the instance" do
        auth = DiscourseActivityPub::Auth::Mastodon.new(domain: domain1)
        auth.create_app
        expect(auth.errors.full_messages.first).to eq(
          "Validation failed: Redirect URI must be an absolute URI.",
        )
      end
    end
  end

  describe "#get_authorize_url" do
    it "returns nil without an app for the domain" do
      expect(DiscourseActivityPub::Auth::Mastodon.get_authorize_url(domain1)).to eq(nil)
    end

    context "with an app for the domain" do
      before do
        PluginStore.set(DiscourseActivityPub::Auth::Mastodon.plugin_store_key, domain1, app_stored)
      end

      it "returns an authorize url" do
        expect(DiscourseActivityPub::Auth::Mastodon.get_authorize_url(domain1)).to eq(
          # https://docs.joinmastodon.org/methods/Mastodon/#query-parameters
          "https://external.com/auth/authorize?client_id=#{client_id}&response_type=code&redirect_uri=#{CGI.escape(redirect_uri)}&scope=#{CGI.escape(DiscourseActivityPub::Auth::Mastodon::SCOPES)}&force_login=true",
        )
      end
    end
  end

  describe "#get_token" do
    context "without an app for the domain" do
      it "returns nil" do
        expect(DiscourseActivityPub::Auth::Mastodon.get_token(domain1, { code: code })).to eq(nil)
      end
    end

    context "with an app for the domain" do
      before do
        PluginStore.set(
          DiscourseActivityPub::Auth::Mastodon.plugin_store_key,
          domain1,
          app_response_body,
        )
      end

      context "with a successful response" do
        before do
          expect_request(
            domain: domain1,
            path: DiscourseActivityPub::Auth::Mastodon::TOKEN_PATH,
            body: token_request_body,
            response: build_response(body: token_response_body, status: 200),
          )
        end

        it "returns an access token" do
          expect(DiscourseActivityPub::Auth::Mastodon.get_token(domain1, { code: code })).to eq(
            access_token,
          )
        end
      end

      context "with an error response" do
        before do
          expect_request(
            domain: domain1,
            path: DiscourseActivityPub::Auth::Mastodon::TOKEN_PATH,
            body: token_request_body,
            response: build_response(body: token_error_body, status: 401),
          )
        end

        it "returns nil" do
          expect(DiscourseActivityPub::Auth::Mastodon.get_token(domain1, { code: code })).to eq(nil)
        end

        it "adds errors to the instance" do
          auth = DiscourseActivityPub::Auth::Mastodon.new(domain: domain1)
          auth.get_token({ code: code })
          expect(auth.errors.full_messages).to include(
            "Client authentication failed due to unknown client, no client authentication included, or unsupported authentication method.",
          )
        end
      end
    end
  end

  describe "#get_actor_id" do
    context "with a successful account response" do
      before do
        expect_request(
          domain: domain1,
          verb: :get,
          path: DiscourseActivityPub::Auth::Mastodon::ACCOUNT_PATH,
          headers: {
            "Authorization" => "Bearer #{access_token}",
          },
          response: build_response(body: account_response_body, status: 200),
        )
      end

      it "returns an actor id" do
        expect(DiscourseActivityPub::Auth::Mastodon.get_actor_id(domain1, access_token)).to eq(
          "https://#{domain1}/users/#{account_response_body[:username]}",
        )
      end
    end

    context "with an error response" do
      before do
        expect_request(
          domain: domain1,
          verb: :get,
          path: DiscourseActivityPub::Auth::Mastodon::ACCOUNT_PATH,
          headers: {
            "Authorization" => "Bearer #{access_token}",
          },
          response: build_response(body: account_error_body, status: 401),
        )
      end

      it "returns nil" do
        expect(DiscourseActivityPub::Auth::Mastodon.get_actor_id(domain1, access_token)).to eq(nil)
      end

      it "adds errors to the instance" do
        auth = DiscourseActivityPub::Auth::Mastodon.new(domain: domain1)
        auth.get_actor_id(access_token)
        expect(auth.errors.full_messages).to include("The access token is invalid")
      end
    end
  end
end
