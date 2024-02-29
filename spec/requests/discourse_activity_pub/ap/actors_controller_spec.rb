# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ActorsController do
  let!(:application) { Fabricate(:discourse_activity_pub_actor_application, local: true) }
  let!(:group) { Fabricate(:discourse_activity_pub_actor_group) }
  let!(:person) { Fabricate(:discourse_activity_pub_actor_person, local: true) }

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
          expect(response.parsed_body).to eq(group.ap.json)
        end
      end

      context "with an application actor" do
        it "returns actor json" do
          get_object(application)
          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq(application.ap.json)
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
      expect(response.parsed_body).to eq(group.ap.json)
    end
  end
end
