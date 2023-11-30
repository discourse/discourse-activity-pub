# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Request do
  let(:object) do
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      id: "https://external.com/u/angus",
      type: "Person",
      inbox: "https://external.com/u/angus/inbox",
      outbox: "https://external.com/u/angus/outbox",
    }.with_indifferent_access
  end

  describe "#get_json_ld" do
    context "with a successful response" do
      before do
        stub_request(:get, object[:id]).with(
          headers: {
            "Accept" => DiscourseActivityPub::JsonLd.content_type_header,
          },
        ).to_return(
          status: 200,
          body: object.to_json,
          headers: {
            "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
          },
        )
      end

      it "returns json ld" do
        expect(described_class.get_json_ld(uri: object[:id])).to eq(object)
      end
    end

    context "with an error response" do
      before do
        stub_request(:get, object[:id]).with(
          headers: {
            "Accept" => DiscourseActivityPub::JsonLd.content_type_header,
          },
        ).to_return(status: 404)
      end

      it "returns nothing" do
        expect(described_class.get_json_ld(uri: object[:id])).to eq(nil)
      end
    end

    context "with a redirect" do
      before do
        url2 = "https://newexternal.com/u/angus"
        stub_request(:get, object[:id]).with(
          headers: {
            "Accept" => DiscourseActivityPub::JsonLd.content_type_header,
          },
        ).to_return(status: 302, body: "", headers: { location: url2 })
        stub_request(:get, url2).to_return(
          status: 200,
          body: object.to_json,
          headers: {
            "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
          },
        )
      end

      it "returns json ld" do
        expect(described_class.get_json_ld(uri: object[:id])).to eq(object)
      end
    end
  end

  describe "#post_json_ld" do
    let(:accept_json) do
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        id: "https://forum.com/c/announcements#activity/accept/#{SecureRandom.hex(8)}",
        type: "Accept",
        actor: "https://forum.com/c/announcements",
        object: "https://external.com/activity/follow/#{SecureRandom.hex(8)}",
        to: "https://external.com/u/angus/inbox",
      }.with_indifferent_access
    end
    let(:post_headers) do
      {
        "Content-Type" => DiscourseActivityPub::JsonLd.content_type_header,
        "Digest" => "SHA-256=#{Digest::SHA256.base64digest(accept_json.to_json)}",
        "Host" => "external.com",
        "Date" => Time.now.utc.httpdate,
      }
    end

    context "with a successful response" do
      before do
        stub_request(:post, object[:inbox]).with(
          headers: post_headers,
          body: accept_json.to_json,
        ).to_return(status: 200)
      end

      it "returns true" do
        expect(described_class.post_json_ld(uri: object[:inbox], body: accept_json)).to eq(true)
      end
    end

    context "with an error response" do
      before do
        stub_request(:post, object[:inbox]).with(
          headers: post_headers,
          body: accept_json.to_json,
        ).to_return(status: 404)
      end

      it "returns false" do
        expect(described_class.post_json_ld(uri: object[:inbox], body: accept_json)).to eq(false)
      end
    end

    context "with a redirect" do
      before do
        url2 = "https://newexternal.com/u/angus/inbox"
        stub_request(:post, object[:inbox]).with(
          headers: post_headers,
          body: accept_json.to_json,
        ).to_return(status: 302, body: "", headers: { location: url2 })
        stub_request(:post, url2).to_return(status: 200)
      end

      it "returns false" do
        expect(described_class.post_json_ld(uri: object[:inbox], body: accept_json)).to eq(false)
      end
    end
  end
end
