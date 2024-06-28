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
    it "returns collection json" do
      get_object(collection)
      expect(response.status).to eq(200)
      expect(parsed_body).to eq(collection.ap.json)
    end

    context "when collection is for a topic with posts" do
      let!(:collection) { Fabricate(:discourse_activity_pub_ordered_collection) }
      let!(:post1) { Fabricate(:post, topic: collection.model) }
      let!(:post2) { Fabricate(:post, topic: collection.model) }
      let!(:note1) do
        Fabricate(:discourse_activity_pub_object_note, model: post1, collection_id: collection.id)
      end
      let!(:note2) do
        Fabricate(:discourse_activity_pub_object_note, model: post2, collection_id: collection.id)
      end

      it "returns collection json with items" do
        get_object(collection)
        expect(response.status).to eq(200)
        expect(parsed_body["orderedItems"].size).to eq(2)
        expect(parsed_body["orderedItems"].first["id"]).to eq(note2.ap_id)
        expect(parsed_body["orderedItems"].last["id"]).to eq(note1.ap_id)
      end
    end
  end
end
