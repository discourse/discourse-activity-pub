# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::URI do
  describe "#DOMAIN_REGEX" do
    it "handles mastodon.social" do
      expect(DiscourseActivityPub::URI::DOMAIN_REGEX.match?("mastodon.social")).to eq(true)
    end
  end

  describe "#local?" do
    before do
      Rails.application.config.hosts = [IPAddr.new("0.0.0.0/0"), IPAddr.new("::/0"), "localhost"]
    end

    after { Rails.application.config.hosts = [] }

    context "with a local uri" do
      it "returns true" do
        expect(described_class.local?("http://localhost.com")).to eq(true)
      end
    end

    context "with a local domain" do
      it "returns true" do
        expect(described_class.local?("localhost.com")).to eq(true)
      end
    end

    context "with a local ip" do
      it "returns true" do
        expect(described_class.local?("0.0.0.0")).to eq(true)
      end
    end

    context "with an external uri" do
      it "returns false" do
        expect(described_class.local?("http://external.com")).to eq(false)
      end
    end

    context "with an external domain" do
      it "returns true" do
        expect(described_class.local?("external.com")).to eq(false)
      end
    end

    context "with an external ip" do
      it "returns true" do
        expect(described_class.local?("192.168.0.1")).to eq(false)
      end
    end
  end
end
