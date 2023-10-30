# frozen_string_literal: true

RSpec.describe SiteController do
  describe "#site" do
    context "with activity pub categories" do
      let!(:category1) { Fabricate(:category) }
      let!(:category2) { Fabricate(:category) }
      let!(:category3) { Fabricate(:category) }

      shared_examples "performance" do
        it "does not increase the number of queries" do
          SiteSetting.activity_pub_enabled = false

          get "/site.json"
          expect(response.status).to eq(200)

          # This is needed to balance the cache clearing that occurs when
          # the categories are saved (below).
          Site.clear_anon_cache!
          Site.clear_cache

          disabled_queries =
            track_sql_queries do
              get "/site.json"
              expect(response.status).to eq(200)
            end

          SiteSetting.activity_pub_enabled = true

          toggle_activity_pub(category1, callbacks: true)
          toggle_activity_pub(category2, callbacks: true)

          enabled_queries =
            track_sql_queries do
              get "/site.json"
              expect(response.status).to eq(200)
            end

          expect(enabled_queries.count).to eq(disabled_queries.count)
        end
      end

      context "without a user" do
        include_examples "performance"
      end

      context "with a user" do
        let!(:user) { Fabricate(:user) }

        before { sign_in(user) }

        include_examples "performance"
      end

    end
  end
end