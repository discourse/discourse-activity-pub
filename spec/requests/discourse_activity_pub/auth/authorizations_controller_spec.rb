# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::AuthorizationsController do
  let!(:user) { Fabricate(:user) }
  let!(:domain1) { "https://external1.com" }
  let!(:domain2) { "https://external2.com" }
  let!(:access_token1) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.auth.error.#{key}")] }
  end

  before do
    sign_in(user)
    user.activity_pub_save_access_token(domain1, access_token1)
    user.activity_pub_save_access_token(domain2, nil)
  end

  describe "#index" do
    it "returns the current user's authorizations" do
      get "/ap/auth/authorizations"
      expect(response.status).to eq(200)
      expect(response.parsed_body[0]["domain"]).to eq(domain1)
      expect(response.parsed_body[0]["access"]).to eq(true)
      expect(response.parsed_body[1]["domain"]).to eq(domain2)
      expect(response.parsed_body[1]["access"]).to eq(false)
    end
  end
end