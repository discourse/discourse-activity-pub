# frozen_string_literal: true

class DiscourseActivityPub::AP::Object::ArticleSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :content, :inReplyTo, :url, :updated

  def inReplyTo
    object.in_reply_to
  end

  def include_inReplyTo?
    object.in_reply_to.present?
  end

  def include_content?
    object.content.present? && !deleted?
  end

  def deleted?
    !object.stored.model || object.stored.model.trashed?
  end
end
