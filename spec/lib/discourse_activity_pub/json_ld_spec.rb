# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::JsonLd do
  let(:object) do
    {
      id: "https://remote.com/u/angus",
      type: "Person",
      inbox: "https://remote.com/u/angus/inbox",
      outbox: "https://remote.com/u/angus/outbox",
    }
  end

  describe "#resolve_object" do
    it "returns objects" do
      expect(described_class.resolve_object(object)).to eq(object)
    end

    it "performs a request on strings" do
      ap_id = "https://remote.com/u/angus"
      DiscourseActivityPub::Request.expects(:get_json_ld).with(uri: ap_id).returns(nil)
      described_class.resolve_object(ap_id)
    end
  end

  describe "#valid_content_type?" do
    it "validates valid content types" do
      expect(described_class.valid_content_type?("application/ld+json")).to eq(true)
      expect(described_class.valid_content_type?("application/activity+json")).to eq(true)
    end

    it "does not validate invalid content types" do
      expect(described_class.valid_content_type?("application/json")).to eq(false)
    end
  end

  describe "#valid_accept?" do
    it "validates valid accept headers" do
      expect(described_class.valid_accept?("application/activity+json, application/ld+json")).to eq(
        true,
      )
    end

    it "validates a mix of valid and invalid accept headers" do
      expect(described_class.valid_accept?("application/activity+json, application/json")).to eq(
        true,
      )
    end

    it "does not validate invalid accept headers" do
      expect(described_class.valid_accept?("application/json")).to eq(false)
    end

    it "does not validate empty accept headers" do
      expect(described_class.valid_accept?(nil)).to eq(false)
    end
  end

  describe "#address_json" do
    let!(:to_actor_id) { "https://remote.com/u/angus" }

    context "with nested json" do
      let!(:json) do
        build_collection_json(
          audience: described_class.public_collection_id,
          items: [
            build_activity_json(
              type: "Create",
              audience: described_class.public_collection_id,
              object: build_object_json(audience: described_class.public_collection_id),
            ),
            build_activity_json(
              type: "Announce",
              audience: described_class.public_collection_id,
              object:
                build_activity_json(
                  type: "Create",
                  audience: described_class.public_collection_id,
                  object: build_object_json(audience: described_class.public_collection_id),
                ),
            ),
            build_activity_json(
              type: "Create",
              audience: described_class.public_collection_id,
              object: build_object_json(audience: described_class.public_collection_id),
            ),
            build_activity_json(type: "Update"),
          ],
        )
      end

      it "copies to to to" do
        addressed_json = described_class.address_json(json, { to: json["audience"] })
        expect(addressed_json["to"]).to eq(json["audience"])

        addressed_json["items"].each do |item|
          expect(item["to"]).to eq(json["audience"])
          expect(item["object"]["to"]).to eq(json["audience"])
        end
      end

      it "copies cc to cc" do
        addressed_json = described_class.address_json(json, { cc: json["audience"] })
        expect(addressed_json["cc"]).to eq(json["audience"])

        addressed_json["items"].each do |item|
          expect(item["cc"]).to eq(json["audience"])
          expect(item["object"]["cc"]).to eq(json["audience"])
        end
      end
    end
  end

  describe "#resolve_icon_url" do
    before do
      described_class.stubs(:safe_icon_url?).returns(true)
    end

    it "returns nil for nil input" do
      expect(described_class.resolve_icon_url(nil)).to be_nil
    end

    it "returns the URL when given a string" do
      expect(described_class.resolve_icon_url("https://example.com/avatar.png")).to eq(
        "https://example.com/avatar.png",
      )
    end

    it "extracts url from a hash" do
      expect(
        described_class.resolve_icon_url({ "url" => "https://example.com/avatar.png" }),
      ).to eq("https://example.com/avatar.png")
    end

    it "extracts url from the first element of an array" do
      expect(
        described_class.resolve_icon_url(
          [{ "url" => "https://example.com/avatar.png" }, { "url" => "https://example.com/other.png" }],
        ),
      ).to eq("https://example.com/avatar.png")
    end

    it "returns nil for an empty array" do
      expect(described_class.resolve_icon_url([])).to be_nil
    end

    it "returns nil for an array with a nil first element" do
      expect(described_class.resolve_icon_url([nil])).to be_nil
    end

    it "returns nil for a hash without a url key" do
      expect(described_class.resolve_icon_url({ "type" => "Image" })).to be_nil
    end

    it "returns nil for a blank string" do
      expect(described_class.resolve_icon_url("")).to be_nil
    end

    it "returns nil when safe_icon_url? returns false" do
      described_class.stubs(:safe_icon_url?).returns(false)
      expect(described_class.resolve_icon_url("https://evil.com/avatar.png")).to be_nil
    end
  end

  describe "#safe_icon_url?" do
    it "returns true for a valid https URL" do
      FinalDestination::SSRFDetector.stubs(:ip_allowed?).returns(true)
      Addrinfo.stubs(:getaddrinfo).returns([stub(ip_address: "93.184.216.34")])
      expect(described_class.safe_icon_url?("https://example.com/avatar.png")).to eq(true)
    end

    it "returns true for a valid http URL" do
      FinalDestination::SSRFDetector.stubs(:ip_allowed?).returns(true)
      Addrinfo.stubs(:getaddrinfo).returns([stub(ip_address: "93.184.216.34")])
      expect(described_class.safe_icon_url?("http://example.com/avatar.png")).to eq(true)
    end

    it "returns false for a non-http scheme" do
      expect(described_class.safe_icon_url?("ftp://example.com/avatar.png")).to eq(false)
    end

    it "returns false for a javascript URI" do
      expect(described_class.safe_icon_url?("javascript:alert(1)")).to eq(false)
    end

    it "returns false when the host is blank" do
      expect(described_class.safe_icon_url?("/relative/path.png")).to eq(false)
    end

    it "returns false when IP is not allowed (SSRF)" do
      FinalDestination::SSRFDetector.stubs(:ip_allowed?).returns(false)
      Addrinfo.stubs(:getaddrinfo).returns([stub(ip_address: "127.0.0.1")])
      expect(described_class.safe_icon_url?("https://example.com/avatar.png")).to eq(false)
    end

    it "returns false for an invalid URI" do
      expect(described_class.safe_icon_url?("ht!tp://not valid")).to eq(false)
    end

    it "returns false on DNS resolution failure" do
      Addrinfo.stubs(:getaddrinfo).raises(SocketError)
      expect(described_class.safe_icon_url?("https://nonexistent.example.com/avatar.png")).to eq(false)
    end
  end

  describe "#base_object_id" do
    let!(:object_id) { "1234" }
    let!(:object_json) { build_object_json(id: object_id) }
    let!(:activity_json) { build_activity_json(type: "Create", object: object_json) }
    let!(:announce_json) { build_activity_json(type: "Announce", object: activity_json) }

    it "returns the base object id" do
      expect(described_class.base_object_id(object_json)).to eq(object_id)
      expect(described_class.base_object_id(activity_json)).to eq(object_id)
      expect(described_class.base_object_id(announce_json)).to eq(object_id)
    end

    it "handles invalid json" do
      invalid_activity_json = activity_json.dup
      invalid_activity_json[:object] = nil
      expect(described_class.base_object_id(invalid_activity_json)).to eq(
        invalid_activity_json[:id],
      )

      invalid_announce_json = announce_json.dup
      invalid_announce_json[:object][:object] = nil
      expect(described_class.base_object_id(invalid_activity_json)).to eq(activity_json[:id])
    end

    it "handles nil and blank strings" do
      expect(described_class.base_object_id("")).to eq(nil)
      expect(described_class.base_object_id(nil)).to eq(nil)
    end
  end
end
