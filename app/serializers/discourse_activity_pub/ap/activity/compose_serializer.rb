# frozen_string_literal: true

class DiscourseActivityPub::AP::Activity::ComposeSerializer < DiscourseActivityPub::AP::ActivitySerializer
  attributes :content

  def include_content?
    object.content.present?
  end
end