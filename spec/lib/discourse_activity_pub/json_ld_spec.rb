# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::JsonLd do
  let(:object) {
    {
      id: "https://external.com/u/angus",
      type: "Person",
      inbox: "https://external.com/u/angus/inbox",
      outbox: "https://external.com/u/angus/outbox"
    }
  }

  describe "#resolve_object" do
    it "returns objects" do
      expect(
        described_class.resolve_object(object)
      ).to eq(object)
    end

    it "performs a request on strings" do
      ap_id = "https://external.com/u/angus"
      DiscourseActivityPub::Request.expects(:get_json_ld).with(uri: ap_id).returns(nil)
      described_class.resolve_object(ap_id)
    end
  end

  describe "#valid_content_type?" do
    it "validates valid content types" do
      expect(
        described_class.valid_content_type?('application/ld+json')
      ).to eq(true)
      expect(
        described_class.valid_content_type?('application/activity+json')
      ).to eq(true)
    end

    it "does not validate invalid content types" do
      expect(
        described_class.valid_content_type?('application/json')
      ).to eq(false)
    end
  end

  describe "#valid_accept?" do
    it "validates valid accept headers" do
      expect(
        described_class.valid_accept?("application/activity+json, application/ld+json")
      ).to eq(true)
    end

    it "does not validate invalid accept headers" do
      expect(
        described_class.valid_accept?("application/activity+json, application/json")
      ).to eq(false)
    end
  end

  describe "#address_json" do
    let!(:to_actor_id) { "https://external.com/u/angus" }

    context "with nested json" do
      let!(:json) {
        build_collection_json(
          audience: described_class.public_collection_id,
          items: [
            build_activity_json(
              type: 'Create',
              audience: described_class.public_collection_id,
              object: build_object_json(
                audience: described_class.public_collection_id
              )
            ), 
            build_activity_json(
              type: 'Announce',
              audience: described_class.public_collection_id,
              object: build_activity_json(
                type: 'Create',
                audience: described_class.public_collection_id,
                object: build_object_json(
                  audience: described_class.public_collection_id
                )
              )
            ),
            build_activity_json(
              type: 'Create',
              audience: described_class.public_collection_id,
              object: build_object_json(
                audience: described_class.public_collection_id
              )
            ),
            build_activity_json(type: "Update")
          ]
        )
      }

      it "copies to to to" do
        addressed_json = described_class.address_json(json, { to: json['audience'] })
        expect(addressed_json['to']).to eq(json['audience'])
  
        addressed_json['items'].each do |item|
          expect(item['to']).to eq(json['audience'])
          expect(item['object']['to']).to eq(json['audience'])
        end
      end

      it "copies cc to cc" do
        addressed_json = described_class.address_json(json, { cc: json['audience'] })
        expect(addressed_json['cc']).to eq(json['audience'])
  
        addressed_json['items'].each do |item|
          expect(item['cc']).to eq(json['audience'])
          expect(item['object']['cc']).to eq(json['audience'])
        end
      end
    end
  end
end