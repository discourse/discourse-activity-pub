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
    before do
      SiteSetting.activity_pub_enabled = false
      setup_logging
    end
    after { teardown_logging }

    it "returns a not enabled error" do
      get_object(object)
      expect_request_error(response, "not_enabled", 403)
    end
  end

  context "with activity pub enabled" do
    before { SiteSetting.activity_pub_enabled = true }

    context "with login required" do
      before do
        SiteSetting.login_required = true
        setup_logging
      end
      after { teardown_logging }

      context "with an object GET" do
        before { setup_logging }
        after { teardown_logging }

        it "returns a not enabled error" do
          get_object(object)
          expect_request_error(response, "not_enabled", 403)
        end
      end

      context "with a POST to a group inbox" do
        it "succeeds" do
          post_to_inbox(group, body: post_body)
          expect(response.status).to eq(202)
        end
      end

      context "with a POST to the users' shared inbox" do
        before { setup_logging }
        after { teardown_logging }

        it "returns a not enabled error" do
          post_to_inbox(nil, url: DiscourseActivityPub.users_shared_inbox, body: post_body)
          expect_request_error(response, "not_enabled", 403)
        end
      end
    end
  end

  context "with an invalid content header" do
    context "with invalid Content-Type header" do
      before { setup_logging }
      after { teardown_logging }

      it "returns bad request" do
        post_to_inbox(group, headers: { "Content-Type" => "application/json" })
        expect_request_error(response, "bad_request", 400)
      end
    end

    context "with invalid Accept header" do
      before { setup_logging }
      after { teardown_logging }

      it "returns bad request" do
        get_from_outbox(group, headers: { "Accept" => "application/json" })
        expect_request_error(response, "bad_request", 400)
      end
    end
  end

  context "with allowed domains" do
    before do
      SiteSetting.activity_pub_allowed_request_origins = "allowed.com"
      setup_logging
    end

    it "allows allowed domains" do
      get_object(object, headers: { ORIGIN: "https://allowed.com" })
      expect(response.status).to eq(200)
    end

    it "blocks not allowed domains" do
      get_object(object, headers: { ORIGIN: "https://notallowed.com" })
      expect_request_error(response, "forbidden", 403)
    end
  end

  context "with blocked domains" do
    before do
      SiteSetting.activity_pub_blocked_request_origins = "notallowed.com"
      setup_logging
    end
    after { teardown_logging }

    it "blocks blocked domains" do
      get_object(object, headers: { ORIGIN: "https://notallowed.com" })
      expect_request_error(response, "forbidden", 403)
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
