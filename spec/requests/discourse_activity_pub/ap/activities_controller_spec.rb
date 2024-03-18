# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::ActivitiesController do
  let!(:activity) { Fabricate(:discourse_activity_pub_activity_create) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ObjectsController }

  before { SiteSetting.activity_pub_require_signed_requests = false }

  context "without a valid activity" do
    before { setup_logging }
    after { teardown_logging }

    it "returns a not found error" do
      get_object(activity, url: "/ap/activity/56")
      expect_request_error(response, "not_found", 404)
    end
  end

  context "without an available base model" do
    fab!(:staff_category) do
      Fabricate(:category).tap do |staff_category|
        staff_category.set_permissions(staff: :full)
        staff_category.save!
      end
    end

    before do
      activity.base_object.model.topic.update(category: staff_category)
      setup_logging
    end
    after { teardown_logging }

    it "returns a not available error" do
      get_object(activity)
      expect_request_error(response, "not_available", 401)
    end
  end

  describe "with an available base model" do
    before do
      category =
        (
          if activity.ap.composition?
            activity.base_object.model.topic.category
          else
            (
              if activity.object.respond_to?(:model)
                activity.object.model
              else
                activity.object&.object&.model
              end
            )
          end
        )
      toggle_activity_pub(category)
    end

    it "returns activity json" do
      get_object(activity)
      expect(response.status).to eq(200)
      expect(parsed_body).to eq(activity.ap.json)
    end

    context "with publishing disabled" do
      before { SiteSetting.login_required = true }

      context "with a composition activity" do
        before { setup_logging }
        after { teardown_logging }

        it "returns a not available error" do
          get_object(activity)
          expect_request_error(response, "not_available", 401)
        end
      end

      context "with a follow actiivty" do
        let!(:activity) { Fabricate(:discourse_activity_pub_activity_follow) }

        it "returns activity json" do
          get_object(activity)
          expect(response.status).to eq(200)
          expect(parsed_body).to eq(activity.ap.json)
        end
      end

      context "with a response actiivty" do
        let!(:activity) { Fabricate(:discourse_activity_pub_activity_follow) }

        it "returns activity json" do
          get_object(activity)
          expect(response.status).to eq(200)
          expect(parsed_body).to eq(activity.ap.json)
        end
      end

      context "with an undo actiivty" do
        let!(:activity) { Fabricate(:discourse_activity_pub_activity_undo) }

        it "returns activity json" do
          get_object(activity)
          expect(response.status).to eq(200)
          expect(parsed_body).to eq(activity.ap.json)
        end
      end
    end
  end
end
