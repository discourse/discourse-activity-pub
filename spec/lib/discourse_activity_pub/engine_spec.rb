# frozen_string_literal: true

RSpec.describe DiscourseActivityPub do
  describe "#enabled" do
    context "without activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = false
      end

      it "returns false" do
        expect(DiscourseActivityPub.enabled).to eq(false)
      end
    end

    context "with activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = true
      end

      it "returns true" do
        expect(DiscourseActivityPub.enabled).to eq(true)
      end

      context "with login required" do
        before do
          SiteSetting.login_required = true
        end

        it "returns false" do
          expect(DiscourseActivityPub.enabled).to eq(true)
        end
      end
    end
  end

  describe "#publishing_enabled" do
    context "without activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = false
      end

      it "returns false" do
        expect(DiscourseActivityPub.publishing_enabled).to eq(false)
      end
    end

    context "with activity pub enabled" do
      before do
        SiteSetting.activity_pub_enabled = true
      end

      context "with login required" do
        before do
          SiteSetting.login_required = true
        end

        it "returns false" do
          expect(DiscourseActivityPub.publishing_enabled).to eq(false)
        end
      end

      context "without login required" do
        before do
          SiteSetting.login_required = false
        end

        it "returns true" do
          expect(DiscourseActivityPub.publishing_enabled).to eq(true)
        end
      end
    end
  end
end