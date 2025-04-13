# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ObjectsController do
  let!(:category) { Fabricate(:category) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group, model: category) }
  let!(:keypair) { OpenSSL::PKey::RSA.new(2048) }
  let!(:actor) do
    Fabricate(:discourse_activity_pub_actor_person, public_key: keypair.public_key.to_pem)
  end
  let!(:topic) { Fabricate(:topic, category: category) }
  let!(:first_post) { Fabricate(:post, topic: topic) }
  let!(:object) { Fabricate(:discourse_activity_pub_object_note, model: first_post) }
  let!(:create_activity) { Fabricate(:discourse_activity_pub_activity_create, object: object) }
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
      expect(response.status).to eq(404)
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

  describe "#show" do
    context "when not requested from a browser" do
      it "returns object json with addressing" do
        get_object(object)
        expect(response.status).to eq(200)
        expect(parsed_body).to eq(object.ap.json)
        expect(parsed_body["to"]).to eq([public_collection_id, group&.ap_id])
        expect(parsed_body["cc"]).to eq(nil)
      end
    end

    context "when requested from a browser" do
      let(:browser_user_agent) do
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edg/75.10240"
      end

      it "redirects to the object's model url" do
        get_object(object, headers: { "HTTP_USER_AGENT" => browser_user_agent })
        expect(response).to redirect_to(first_post.url)
      end

      context "when object's model is trashed" do
        before { first_post.trash! }

        it "renders a 404 page" do
          get_object(object, headers: { "HTTP_USER_AGENT" => browser_user_agent })
          expect(response.status).to eq(404)
          expect(response.body).to include(I18n.t("page_not_found.title"))
        end
      end
    end

    context "when tombstoned" do
      before { object.update(ap_type: DiscourseActivityPub::AP::Object::Tombstone.type) }

      it "returns not found" do
        get_object(object)
        expect(response.status).to eq(404)
      end
    end
  end
end
