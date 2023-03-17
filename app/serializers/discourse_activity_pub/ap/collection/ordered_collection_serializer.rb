# frozen_string_literal: true

class DiscourseActivityPub::AP::Collection::OrderedCollectionSerializer < DiscourseActivityPub::AP::CollectionSerializer
  attributes :ordered_items

  def ordered_items
    object.ordered_items.map(&:json)
  end
end