# frozen_string_literal: true

class DiscourseActivityPub::AP::ActivitySerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :actor

  def attributes(*args)
    hash = super
    hash[:object] = _object
    hash
  end

  def _object
    object.object
  end
end