# frozen_string_literal: true

Fabricator(:discourse_activity_pub_collection) do
  ap_type { "Collection" }
  local { true }
end

Fabricator(:discourse_activity_pub_ordered_collection, from: :discourse_activity_pub_collection) do
  ap_type { DiscourseActivityPub::AP::Collection::OrderedCollection.type }
  model { Fabricate(:topic) }
end
