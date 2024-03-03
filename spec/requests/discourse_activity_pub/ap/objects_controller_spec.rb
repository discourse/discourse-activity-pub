# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ObjectsController do
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:keypair) { OpenSSL::PKey::RSA.new(2048) }
  let!(:actor) do
    Fabricate(:discourse_activity_pub_actor_person, public_key: keypair.public_key.to_pem)
  end
  let!(:object) { Fabricate(:discourse_activity_pub_object_note) }
  let!(:post_body) { build_activity_json(object: group) }

  before do
    SiteSetting.activity_pub_require_signed_requests = false
    toggle_activity_pub(group.model)
  end

  context "without activity pub enabled" do
    before { SiteSetting.activity_pub_enabled = false }

    it "returns a not enabled error" do
      get_object(object)
      expect(response.status).to eq(403)
      expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
    end
  end

  context "with activity pub enabled" do
    before { SiteSetting.activity_pub_enabled = true }

    context "with login required" do
      before { SiteSetting.login_required = true }

      context "with an object GET" do
        it "returns a not enabled error" do
          get_object(object)
          expect(response.status).to eq(403)
          expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
        end
      end

      context "with a POST to a group inbox" do
        it "succeeds" do
          post_to_inbox(group, body: post_body)
          expect(response.status).to eq(202)
        end
      end

      context "with a POST to the users' shared inbox" do
        it "returns a not enabled error" do
          post_to_inbox(nil, url: DiscourseActivityPub.users_shared_inbox, body: post_body)
          expect(response.status).to eq(403)
          expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
        end
      end
    end
  end

  context "with an invalid content header" do
    context "with invalid Content-Type header" do
      it "returns bad request" do
        post_to_inbox(group, headers: { "Content-Type" => "application/json" })
        expect(response.status).to eq(400)
        expect(response.parsed_body).to eq(activity_request_error("bad_request"))
      end
    end

    context "with invalid Accept header" do
      it "returns bad request" do
        get_from_outbox(group, headers: { "Accept" => "application/json" })
        expect(response.status).to eq(400)
        expect(response.parsed_body).to eq(activity_request_error("bad_request"))
      end
    end
  end

  context "with allowed domains" do
    before { SiteSetting.activity_pub_allowed_request_origins = "allowed.com" }

    it "allows allowed domains" do
      get_object(object, headers: { ORIGIN: "https://allowed.com" })
      expect(response.status).to eq(200)
    end

    it "blocks not allowed domains" do
      get_object(object, headers: { ORIGIN: "https://notallowed.com" })
      expect(response.status).to eq(403)
    end
  end

  context "with blocked domains" do
    before { SiteSetting.activity_pub_blocked_request_origins = "notallowed.com" }

    it "blocks blocked domains" do
      get_object(object, headers: { ORIGIN: "https://notallowed.com" })
      expect(response.status).to eq(403)
    end

    it "allows unblocked domains" do
      get_object(object, headers: { ORIGIN: "https://allowed.com" })
      expect(response.status).to eq(200)
    end
  end

  describe "#show" do
    it "returns a object json" do
      get_object(object)
      expect(response.status).to eq(200)
      expect(parsed_body).to eq(object.ap.json)
    end
  end
end
