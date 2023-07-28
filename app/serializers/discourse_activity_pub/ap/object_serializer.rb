# frozen_string_literal: true

class DiscourseActivityPub::AP::ObjectSerializer < ActiveModel::Serializer
  attributes :id,
             :type,
             :to

  def attributes(*args)
    hash = super
    hash["@context"] = context
    hash
  end

  def context
    object.context
  end

  def to
    object.to
  end

  def include_to?
    object.to.present?
  end
end