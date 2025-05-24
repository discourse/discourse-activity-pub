# frozen_string_literal: true

class DiscourseActivityPub::AP::CollectionSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :items, :totalItems

  def items
    object.items.map(&:json)
  end

  def totalItems
    object.total_items
  end
end
