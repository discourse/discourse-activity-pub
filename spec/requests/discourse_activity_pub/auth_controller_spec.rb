# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AuthController do
  let!(:user) { Fabricate(:user) }
  let!(:domain1) { "https://external1.com" }
  let!(:domain2) { "https://external2.com" }
  let!(:access_token1) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.auth.error.#{key}")] }
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
        before do
          SiteSetting.activity_pub_enabled = false
        end

        it "returns a not enabled error" do
          get "/ap/auth"
          expect(response.status).to eq(403)
          expect(response.parsed_body).to eq(build_error("not_enabled"))
        end
      end

      context "with activity pub enabled" do
        before do
          SiteSetting.activity_pub_enabled = true
        end

        context "with login required" do
          before do
            SiteSetting.login_required = true
          end

          it "returns a not enabled error" do
            get "/ap/auth"
            expect(response.status).to eq(403)
            expect(response.parsed_body).to eq(build_error("not_enabled"))
          end
        end

        it "succeeds" do
          get "/ap/auth"
          expect(response).to be_successful
        end
      end
    end
  end
end