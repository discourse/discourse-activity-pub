# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Admin::AdminController do
  fab!(:admin)
  fab!(:moderator)

  it { expect(described_class).to be < Admin::AdminController }

  describe "#index" do
    context "when authenticated" do
      context "as an admin" do
        before { sign_in(admin) }

        context "when activity pub is disabled" do
          before { SiteSetting.activity_pub_enabled = false }

          it "returns a not enabled error" do
            get "/admin/ap.json"
            expect_not_enabled(response)
          end
        end

        context "when activity pub is enabled" do
          before { SiteSetting.activity_pub_enabled = true }

          it "permits access with a 202 response" do
            get "/admin/ap.json"
            expect(response.status).to eq(202)
          end
        end
      end
    end
  end
end
