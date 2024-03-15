# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Admin::AdminController do
  fab!(:admin)
  fab!(:moderator)

  it { expect(described_class).to be < Admin::AdminController }

  describe "#index" do
    context "when authenticated" do
      context "as an admin" do
        before { sign_in(admin) }

        context "when the activity pub plugin is disabled" do
          before { SiteSetting.activity_pub_enabled = false }

          it "denies access with a 404 response" do
            get "/admin/ap.json"
            expect(response.status).to eq(404)
            expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
          end
        end

        context "when the activity pub plugin is enabled" do
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
