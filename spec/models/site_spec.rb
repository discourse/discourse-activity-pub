# frozen_string_literal: true

RSpec.describe Site do
  describe "#activity_pub_enabled" do
    context "without activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = false
      end

      it "returns false" do
        expect(Site.activity_pub_enabled).to eq(false)
      end
    end

    context "with activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = true
      end

      it "returns true" do
        expect(Site.activity_pub_enabled).to eq(true)
      end

      context "with login required" do
        before do
          SiteSetting.login_required = true
        end

        it "returns false" do
          expect(Site.activity_pub_enabled).to eq(false)
        end
      end
    end
  end
end
