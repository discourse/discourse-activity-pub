# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::NodeinfoController do
  describe "#index" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        get "/.well-known/nodeinfo"
        expect(response.status).to eq(404)
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      it "returns a JRD" do
        get "/.well-known/nodeinfo"
        expect(response.status).to eq(200)

        body = JSON.parse(response.body)
        expect(body["links"][0]["rel"]).to eq(
          "http://nodeinfo.diaspora.software/ns/schema/#{DiscourseActivityPub::Nodeinfo::SUPPORTED_VERSION}",
        )
        expect(body["links"][0]["href"]).to eq(
          "http://test.localhost/nodeinfo/#{DiscourseActivityPub::Nodeinfo::SUPPORTED_VERSION}",
        )
      end
    end
  end
end
