# frozen_string_literal: true

class DiscourseActivityPub::AP::Object::ArticleSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :content, :inReplyTo, :url, :updated, :attachment

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

  def attachment
    object.attachment.map(&:json)
  end

  def include_attachment?
    object.attachment.present?
  end
end
