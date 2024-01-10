# frozen_string_literal: true

RSpec.describe DiscourseActivityPub do
  describe "#enabled" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns false" do
        expect(DiscourseActivityPub.enabled).to eq(false)
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      it "returns true" do
        expect(DiscourseActivityPub.enabled).to eq(true)
      end

      context "with login required" do
        before { SiteSetting.login_required = true }

        it "returns false" do
          expect(DiscourseActivityPub.enabled).to eq(true)
        end
      end
    end
  end

  describe "#publishing_enabled" do
    context "without activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = false }

      it "returns false" do
        expect(DiscourseActivityPub.publishing_enabled).to eq(false)
      end
    end

    context "with activity pub enabled" do
      before { SiteSetting.activity_pub_enabled = true }

      context "with login required" do
        before { SiteSetting.login_required = true }

        it "returns false" do
          expect(DiscourseActivityPub.publishing_enabled).to eq(false)
        end
      end

      context "without login required" do
        before { SiteSetting.login_required = false }

        it "returns true" do
          expect(DiscourseActivityPub.publishing_enabled).to eq(true)
        end
      end
    end
  end
end
