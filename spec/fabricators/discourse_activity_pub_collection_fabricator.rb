# frozen_string_literal: true

Fabricator(:discourse_activity_pub_collection) do
  ap_type { "Collection" }
  local { true }

  before_create do |object|
    if !object.local && !object.ap_id
      object.ap_id = "https://external.com/object/#{ap_type.downcase}/#{SecureRandom.hex(8)}"
    end
  end
end

Fabricator(:discourse_activity_pub_ordered_collection, from: :discourse_activity_pub_collection) do
  ap_type { DiscourseActivityPub::AP::Collection::OrderedCollection.type }
  model { Fabricate(:topic) }
end
