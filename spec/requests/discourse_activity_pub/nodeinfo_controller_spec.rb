# frozen_string_literal: true

require "json_schemer"

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
          "http://nodeinfo.diaspora.software/ns/schema/#{DiscourseActivityPub::Nodeinfo::VERSION}",
        )
        expect(body["links"][0]["href"]).to eq(
          "http://test.localhost/nodeinfo/#{DiscourseActivityPub::Nodeinfo::VERSION}",
        )
      end
    end
  end

  describe "#show" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns a not enabled error" do
        get "/nodeinfo/#{DiscourseActivityPub::Nodeinfo::VERSION}"
        expect(response.status).to eq(404)
      end
    end

    context "with activity pub enabled" do
      let!(:version_schema) do
        ## See https://github.com/jhass/nodeinfo/blob/main/schemas/2.1/schema.json
        JSON.parse(
          File.open(
            File.join(
              File.expand_path("../..", __dir__),
              "fixtures",
              "nodeinfo",
              DiscourseActivityPub::Nodeinfo::VERSION,
              "schema.json",
            ),
          ).read,
        ).with_indifferent_access
      end

      before do
        SiteSetting.activity_pub_enabled = true
        2.times do
          post = Fabricate(:post, user: Fabricate(:active_user, last_seen_at: 2.days.ago))
          Fabricate(
            :post,
            user: Fabricate(:active_user, last_seen_at: 33.days.ago),
            reply_to_post_number: post.post_number,
          )
        end
        2.times { Fabricate(:post, user: Fabricate(:user, staged: true)) }
        2.times { Fabricate(:post, user: Fabricate(:active_user, last_seen_at: 200.days.ago)) }
      end

      it "returns nodeinfo" do
        get "/nodeinfo/#{DiscourseActivityPub::Nodeinfo::VERSION}"
        expect(response.status).to eq(200)

        json = response.parsed_body
        schemer = ::JSONSchemer.schema(version_schema)
        expect(schemer.valid?(json)).to eq(true)

        expect(json["version"]).to eq(DiscourseActivityPub::Nodeinfo::VERSION)
        expect(json["software"]).to eq(
          {
            name: DiscourseActivityPub::Nodeinfo::SOFTWARE_NAME,
            version: Discourse::VERSION::STRING,
          }.as_json,
        )
        expect(json["protocols"]).to eq(DiscourseActivityPub::Nodeinfo::SUPPORTED_PROTOCOLS)
        expect(json["services"]).to eq(
          {
            inbound: DiscourseActivityPub::Nodeinfo::SUPPORTED_INBOUND_SERVICES,
            outbound: DiscourseActivityPub::Nodeinfo::SUPPORTED_OUTBOUND_SERVICES,
          }.as_json,
        )
        expect(json["usage"]["users"]).to eq(
          { total: 6, activeMonth: 2, activeHalfyear: 4 }.as_json,
        )
        expect(json["usage"]["localPosts"]).to eq(4)
        expect(json["usage"]["localComments"]).to eq(2)
        expect(json["openRegistrations"]).to eq(!SiteSetting.login_required)
        expect(json["metadata"]).to eq(
          { nodeName: SiteSetting.title, nodeDescription: SiteSetting.site_description }.as_json,
        )
      end
    end
  end
end
