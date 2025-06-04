# frozen_string_literal: true

class DiscourseActivityPub::AP::Collection::OrderedCollectionSerializer < DiscourseActivityPub::AP::CollectionSerializer
  attributes :orderedItems

  def orderedItems
    object.ordered_items.map(&:json)
  end

  def include_items?
    false
  end
end
