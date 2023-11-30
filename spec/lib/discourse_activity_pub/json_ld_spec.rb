# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::JsonLd do
  let(:object) do
    {
      id: "https://external.com/u/angus",
      type: "Person",
      inbox: "https://external.com/u/angus/inbox",
      outbox: "https://external.com/u/angus/outbox",
    }
  end

  describe "#resolve_object" do
    it "returns objects" do
      expect(described_class.resolve_object(object)).to eq(object)
    end

    it "performs a request on strings" do
      ap_id = "https://external.com/u/angus"
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

    it "does not validate invalid accept headers" do
      expect(described_class.valid_accept?("application/activity+json, application/json")).to eq(
        false,
      )
    end
  end
end
