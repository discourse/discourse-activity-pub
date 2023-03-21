# frozen_string_literal: true

class DiscourseActivityPub::AP::CollectionSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :items,
             :total_items

  def items
    object.items.map(&:json)
  end
end