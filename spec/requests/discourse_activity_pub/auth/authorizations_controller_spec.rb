# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Auth::AuthorizationsController do
  let!(:user) { Fabricate(:user) }
  let!(:domain1) { "https://external1.com" }
  let!(:domain2) { "https://external2.com" }
  let!(:actor_id1) { "https://external1.com/users/angus" }
  let!(:access_token1) { "ZA-Yj3aBD8U8Cm7lKUp-lm9O9BmDgdhHzDeqsY8tlL0" }

  def build_error(key)
    { "errors" => [I18n.t("discourse_activity_pub.auth.error.#{key}")] }
  end

  before do
    sign_in(user)
    user.activity_pub_save_access_token(domain1, access_token1)
    user.activity_pub_save_access_token(domain2, nil)
    user.activity_pub_save_actor_id(domain1, actor_id1)
  end

  it { expect(described_class).to be < DiscourseActivityPub::AuthController }

  describe "#index" do
    it "returns the current user's authorizations" do
      get "/ap/auth/authorizations"
      expect(response.status).to eq(200)
      expect(response.parsed_body.size).to eq(1)
      expect(response.parsed_body[0]["actor_id"]).to eq(actor_id1)
      expect(response.parsed_body[0]["domain"]).to eq(domain1)
      expect(response.parsed_body[0]["access"]).to eq(true)
    end
  end
end