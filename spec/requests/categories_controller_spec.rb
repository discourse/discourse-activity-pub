# frozen_string_literal: true

RSpec.describe CategoriesController do
  describe "#index" do
    context "with activity pub categories" do
      let!(:category1) { Fabricate(:category) }
      let!(:category2) { Fabricate(:category) }
      let!(:category3) { Fabricate(:category) }

      shared_examples "performance" do
        it "does not increase the number of queries" do
          SiteSetting.activity_pub_enabled = false
          # prime caches
          get "/categories.json"
          expect(response.status).to eq(200)

          disabled_queries =
            track_sql_queries do
              get "/categories.json"
              expect(response.status).to eq(200)
            end

          SiteSetting.activity_pub_enabled = true
          toggle_activity_pub(category1, callbacks: true)
          toggle_activity_pub(category2, callbacks: true)

          enabled_queries =
            track_sql_queries do
              get "/categories.json"
              expect(response.status).to eq(200)
            end

          expect(enabled_queries.count).to eq(disabled_queries.count)
        end
      end

      include_examples "performance"

      context "when topics are loaded" do
        before do
          [category1, category2].each do |category|
            5.times do
              topic = Fabricate(:topic, category: category)
              collection = Fabricate(:discourse_activity_pub_ordered_collection, model: topic)
              post = Fabricate(:post, topic: topic)
              note = Fabricate(:discourse_activity_pub_object_note, model: post, collection_id: collection.id)
              activity = Fabricate(:discourse_activity_pub_activity_create, object: note)
            end
          end

          CategoryFeaturedTopic.feature_topics
          SiteSetting.desktop_category_page_style = "categories_with_featured_topics"
        end

        include_examples "performance"
      end
    end
  end
end