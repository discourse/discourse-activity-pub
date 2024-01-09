# frozen_string_literal: true

RSpec.describe ListController do
  describe "#index" do
    context "with activity pub topics" do
      fab!(:category1) { Fabricate(:category) }
      fab!(:category2) { Fabricate(:category) }
      fab!(:category3) { Fabricate(:category) }
      fab!(:topic_ids) do
        topic_ids = []
        [category1, category2].each do |category|
          5.times do
            topic = Fabricate(:topic, category: category)
            topic_ids << topic.id
            collection = Fabricate(:discourse_activity_pub_ordered_collection, model: topic)
            post = Fabricate(:post, topic: topic)
            note =
              Fabricate(
                :discourse_activity_pub_object_note,
                model: post,
                collection_id: collection.id,
              )
            activity = Fabricate(:discourse_activity_pub_activity_create, object: note)
          end
        end
        topic_ids
      end

      def track_index_queries
        track_sql_queries do
          get "/latest.json"
          expect(response.status).to eq(200)
          body = response.parsed_body
          expect(body["topic_list"]["topics"].map { |t| t["id"] }).to contain_exactly(*topic_ids)
        end
      end

      context "without a logged in user" do
        it "does not increase the number of queries" do
          SiteSetting.activity_pub_enabled = false

          # prime caches
          get "/latest.json"
          expect(response.status).to eq(200)

          disabled_queries = track_index_queries

          SiteSetting.activity_pub_enabled = true
          toggle_activity_pub(category1, callbacks: true)
          toggle_activity_pub(category2, callbacks: true)

          enabled_queries = track_index_queries

          expect(enabled_queries.count).to eq(disabled_queries.count)
        end
      end

      context "with a logged in user" do
        let!(:user) { Fabricate(:user) }

        before { sign_in(user) }

        it "does not increase the number of queries" do
          SiteSetting.activity_pub_enabled = false

          # prime caches
          get "/latest.json"
          expect(response.status).to eq(200)

          disabled_queries = track_index_queries

          SiteSetting.activity_pub_enabled = true
          toggle_activity_pub(category1, callbacks: true)
          toggle_activity_pub(category2, callbacks: true)

          enabled_queries = track_index_queries

          expect(enabled_queries.count).to eq(disabled_queries.count)
        end
      end
    end
  end
end
