# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ActorsController do
  let!(:application) { Fabricate(:discourse_activity_pub_actor_application, local: true) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:person) do
    Fabricate(:discourse_activity_pub_actor_person, local: true, model: Fabricate(:user))
  end

  it { expect(described_class).to be < DiscourseActivityPub::AP::ObjectsController }

  before { SiteSetting.activity_pub_require_signed_requests = false }

  context "without a valid actor" do
    before { setup_logging }
    after { teardown_logging }

    it "returns a not found error" do
      get_object(group, url: "/ap/actor/56")
      expect_request_error(response, "not_found", 404)
    end
  end

  context "without a public actor" do
    before do
      group.model.set_permissions(admins: :full)
      group.model.save!
      setup_logging
    end
    after { teardown_logging }

    it "returns a not available error" do
      get_object(group)
      expect_request_error(response, "not_available", 401)
    end
  end

  context "without activity pub ready on actor model" do
    before { setup_logging }
    after { teardown_logging }

    it "returns a not available error" do
      get_object(group)
      expect_request_error(response, "not_available", 403)
    end
  end

  context "with activity pub ready on actor model" do
    before { toggle_activity_pub(group.model) }

    context "with publishing disabled" do
      before { SiteSetting.login_required = true }

      context "with a group actor" do
        it "returns actor json" do
          get_object(group)
          expect(response.status).to eq(200)
          expect(parsed_body).to eq(group.reload.ap.json)
        end
      end

      context "with an application actor" do
        it "returns actor json" do
          get_object(application)
          expect(response.status).to eq(200)
          expect(parsed_body).to eq(application.ap.json)
        end
      end

      context "with a person actor" do
        before { setup_logging }
        after { teardown_logging }

        it "returns a not available error" do
          get_object(person)
          expect_request_error(response, "not_available", 401)
        end
      end
    end

    it "returns actor json" do
      get_object(group)
      expect(response.status).to eq(200)
      expect(parsed_body).to eq(group.reload.ap.json)
    end

    it "ensures actor has required attributes" do
      person.update_columns(inbox: "/inbox", outbox: "/outbox")
      get_object(person)
      expect(parsed_body["inbox"]).to include(person.ap_key)
      expect(parsed_body["outbox"]).to include(person.ap_key)
    end

    context "when requested from a browser" do
      let(:browser_user_agent) do
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edg/75.10240"
      end

      context "with a group actor" do
        it "redirects to the group model url" do
          get_object(group, headers: { "HTTP_USER_AGENT" => browser_user_agent })
          expect(response).to redirect_to(group.model.url)
        end
      end
    end
  end
end
