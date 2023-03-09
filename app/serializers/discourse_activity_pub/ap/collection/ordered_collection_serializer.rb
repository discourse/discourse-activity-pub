# frozen_string_literal: true

class DiscourseActivityPub::AP::Collection::OrderedCollectionSerializer < DiscourseActivityPub::AP::CollectionSerializer
  attributes :ordered_items

  def ordered_items
    serialize_items(object.ordered_items)
  end
end