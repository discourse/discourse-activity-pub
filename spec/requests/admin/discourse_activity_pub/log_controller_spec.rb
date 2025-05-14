# frozen_string_literal: true

RSpec.describe Admin::DiscourseActivityPub::LogController do
  fab!(:admin)

  it { expect(described_class).to be < Admin::AdminController }

  before { sign_in(admin) }

  describe "#index" do
    let!(:log1) { Fabricate(:discourse_activity_pub_log) }
    let!(:log2) { Fabricate(:discourse_activity_pub_log) }

    it "returns logs" do
      get "/admin/plugins/ap/log.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"].size).to eq(2)
    end

    it "paginates" do
      Admin::DiscourseActivityPub::LogController.any_instance.stubs(:page_limit).returns(1)

      get "/admin/plugins/ap/log.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"].size).to eq(1)
      expect(response.parsed_body["logs"][0]["id"]).to eq(log2.id)
      expect(response.parsed_body["meta"]["total"]).to eq(2)
      expect(response.parsed_body["meta"]["load_more_url"]).to eq(
        "/admin/plugins/ap/log.json?offset=1",
      )

      get "/admin/plugins/ap/log.json?offset=1"
      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"].size).to eq(1)
      expect(response.parsed_body["logs"][0]["id"]).to eq(log1.id)
    end
  end
end
