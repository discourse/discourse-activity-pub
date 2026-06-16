# frozen_string_literal: true

class DiscourseActivityPub::AP::Activity::UndoSerializer < DiscourseActivityPub::AP::ActivitySerializer
  def _object
    return super if DiscourseActivityPub.publishing_enabled

    object.object&.id
  end
end
