# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Webfinger do
  let!(:account) { 
    File.open(
      File.join(File.expand_path("../../..", __dir__), "spec", "fixtures", "account.json")
    ).read
  }

  def build_handle(domain)
    "username@#{domain}"
  end

  def build_url(domain, handle)
    query = "resource=#{DiscourseActivityPub::Webfinger::ACCOUNT_SCHEME}:#{handle}"
    path = "#{DiscourseActivityPub::Webfinger::PATH}?#{query}"
    "https://#{domain}/#{path}"
  end

  describe "#find_by_handle" do

    def perform(handle)
      DiscourseActivityPub::Webfinger.find_by_handle(handle)
    end

    context "with a local domain" do
      let!(:handle) { build_handle(DiscourseActivityPub.host) }

      it "returns nil" do
        expect(perform(handle)).to eq(nil)
      end
    end

    context "with a remote domain" do
      let!(:domain) { "external.com" }
      let!(:handle) { build_handle(domain) }

      context "with an inaccessible remote" do
        before do
          stub_request(:get, build_url(domain, handle))
            .to_return(status: 404)
        end

        it "returns nil" do
          expect(perform(handle)).to eq(nil)
        end
      end

      context "with an accessible remote" do
        before do
          stub_request(:get, build_url(domain, handle))
            .to_return(body: account, status: 200)
        end

        it "returns response json" do
          expect(perform(handle)).to eq(JSON.parse(account))
        end
      end
    end
  end

  describe "#find_id_by_handle" do

    def perform(handle)
      DiscourseActivityPub::Webfinger.find_id_by_handle(handle)
    end

    context "with a local handle" do
      let!(:handle) { build_handle(DiscourseActivityPub.host) }

      it "returns nil" do
        expect(perform(handle)).to eq(nil)
      end
    end

    context "with a remote handle" do
      let!(:domain) { "external.com" }
      let!(:handle) { build_handle(domain) }

      context "with an inaccessible remote" do
        before do
          stub_request(:get, build_url(domain, handle))
            .to_return(status: 404)
        end

        it "returns nil" do
          expect(perform(handle)).to eq(nil)
        end
      end

      context "with an accessible remote" do
        before do
          stub_request(:get, build_url(domain, handle))
            .to_return(body: account, status: 200)
        end

        it "returns account id" do
          account_json = JSON.parse(account)
          expect(perform(handle)).to eq(account_json["links"][1]['href'])
        end
      end
    end
  end
end