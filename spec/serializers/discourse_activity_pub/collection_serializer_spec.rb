# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::AP::CollectionSerializer do
  let!(:accept) { Fabricate(:discourse_activity_pub_activity_accept) }

  def get_ap_serializer(object)
    DiscourseActivityPub::AP::CollectionSerializer.new(object, root: false).as_json
  end

  def get_ap_collection
    DiscourseActivityPub::AP::Collection.new(model: accept.actor.model, collection_for: 'inbox')
  end

  it "serializes collection attributes correctly" do
    collection = get_ap_collection
    serialized = get_ap_serializer(collection)

    expect(serialized['@context']).to eq(DiscourseActivityPub::JsonLd::ACTIVITY_STREAMS_CONTEXT)
    expect(serialized[:id]).to eq(collection.id)
    expect(serialized[:type]).to eq(collection.type)
    expect(serialized[:total_items]).to eq(collection.total_items)
    expect(serialized[:items]).to eq([
      DiscourseActivityPub::AP::Activity::AcceptSerializer.new(
        DiscourseActivityPub::AP::Activity::Accept.new(activity: accept)
      ).as_json
    ])
  end
end
