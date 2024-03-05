# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::CollectionsController do
  let(:collection) { Fabricate(:discourse_activity_pub_ordered_collection) }

  it { expect(described_class).to be < DiscourseActivityPub::AP::ObjectsController }

  before { SiteSetting.activity_pub_require_signed_requests = false }

  context "without a valid collection" do
    before { setup_logging }
    after { teardown_logging }

    it "returns a not found error" do
      get_object(collection, url: "/ap/collection/56")
      expect_request_error(response, "not_found", 404)
    end
  end

  context "without a publicly available topic" do
    fab!(:staff_category) do
      Fabricate(:category).tap do |staff_category|
        staff_category.set_permissions(staff: :full)
        staff_category.save!
      end
    end

    before do
      collection.model.update(category: staff_category)
      setup_logging
    end
    after { teardown_logging }

    it "returns a not available error" do
      get_object(collection)
      expect_request_error(response, "not_available", 401)
    end
  end

  describe "#show" do
    before { toggle_activity_pub(collection.model) }

    it "returns collection json" do
      get_object(collection)
      expect(response.status).to eq(200)
      expect(parsed_body).to eq(collection.ap.json)
    end
  end
end
