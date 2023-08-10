# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::OAuthController do
  let!(:user) { Fabricate(:user) }
  let!(:domain1) { "https://external1.com" }
  let!(:domain2) { "https://external2.com" }
  let!(:redirect_uri) { "#{Discourse.base_url}/#{DiscourseActivityPub::Auth::OAuth::REDIRECT_PATH}" }
  let!(:client_id) { "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM" }
  let!(:client_secret) { "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw" }
  let!(:access_token1) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }
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

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.oauth.error.#{key}")] }
  end

  before do
    sign_in(user)
    user.activity_pub_save_access_token(domain1, access_token1)
    user.activity_pub_save_access_token(domain2, nil)
  end

  describe "#create" do
    context "without a domain param" do
      it "returns a not enabled error" do
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
          oauth = DiscourseActivityPub::Auth::OAuth.new(domain1)
          oauth.add_error("Not a valid domain")
          DiscourseActivityPub::Auth::OAuth.stubs(:new).with(domain1).returns(oauth)
          DiscourseActivityPub::Auth::OAuth.any_instance.stubs(:create_app).returns(nil)
        end

        it "does not create an app and returns the error" do
          post "/ap/auth/oauth", params: { domain: domain1 }
          expect(response.status).to eq(422)
          expect(response.parsed_body['errors'].first).to eq("Not a valid domain")
        end
      end
    end
  end
end