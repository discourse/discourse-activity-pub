# frozen_string_literal: true

class DiscourseActivityPub::AP::Activity::ResponseSerializer < DiscourseActivityPub::AP::ActivitySerializer
  attributes :summary

  def include_summary?
    object.summary.present?
  end
end