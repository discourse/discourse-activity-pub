# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::CollectionSerializer do
  let!(:accept) { Fabricate(:discourse_activity_pub_activity_accept) }

  def get_ap_serialized_collection(object)
    DiscourseActivityPub::AP::CollectionSerializer.new(object, root: false).as_json
  end

  def get_ap_collection(actor)
    DiscourseActivityPub::AP::Collection.new(stored: actor, collection_for: 'inbox')
  end

  it "serializes collection attributes correctly" do
    collection = get_ap_collection(accept.actor)
    serialized_collection = get_ap_serialized_collection(collection)

    expect(serialized_collection['@context']).to eq(DiscourseActivityPub::JsonLd::ACTIVITY_STREAMS_CONTEXT)
    expect(serialized_collection[:id]).to eq(collection.id)
    expect(serialized_collection[:type]).to eq(collection.type)
    expect(serialized_collection[:total_items]).to eq(collection.total_items)
    expect(serialized_collection[:items]).to eq([
      DiscourseActivityPub::AP::Activity::AcceptSerializer.new(
        DiscourseActivityPub::AP::Activity::Accept.new(stored: accept),
        root: false
      ).as_json
    ])
  end
end
