# frozen_string_literal: true

class DiscourseActivityPub::AP::Object::NoteSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :content

  def include_content?
    object.content.present?
  end
end