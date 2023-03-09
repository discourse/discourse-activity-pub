# frozen_string_literal: true

class DiscourseActivityPub::AP::CollectionSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :items,
             :total_items

  def items
    serialize_items(object.items)
  end

  protected

  def serialize_items(items)
    items.map do |item|
      serializer_klass = "DiscourseActivityPub::AP::Activity::#{item.type}Serializer".classify.constantize
      serializer_klass.new(item).as_json
    end
  end
end