# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ObjectsController do
  let(:object) { Fabricate(:discourse_activity_pub_object_note) }

  context "without activity pub enabled" do
    before do
      SiteSetting.activity_pub_enabled = false
    end

    it "returns a not enabled error" do
      get_object(object)
      expect(response.status).to eq(403)
      expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
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
        get_object(object)
        expect(response.status).to eq(403)
        expect(response.parsed_body).to eq(activity_request_error("not_enabled"))
      end
    end

    context "without login required" do
      let(:group) { Fabricate(:discourse_activity_pub_actor_group) }

      context "with invalid Content-Type header" do
        it "returns bad request" do
          post_to_inbox(group, custom_content_header: "application/json")
          expect(response.status).to eq(400)
          expect(response.parsed_body).to eq(activity_request_error("bad_request"))
        end
      end

      context "with invalid Accept header" do
        it "returns bad request" do
          get_from_outbox(group, custom_content_header: "application/json")
          expect(response.status).to eq(400)
          expect(response.parsed_body).to eq(activity_request_error("bad_request"))
        end
      end
    end
  end

  describe "#show" do
    it "returns a object json" do
      get_object(object)
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(object.ap.json)
    end
  end
end
