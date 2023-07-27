# frozen_string_literal: true

class DiscourseActivityPub::AP::Object::ArticleSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :content,
             :url,
             :published,
             :updated,
             :inReplyTo

  def inReplyTo
    object.in_reply_to
  end

  def include_content?
    object.content.present? && !deleted?
  end

  def include_url?
    object.url.present?
  end

  def include_updated?
    object.updated.present?
  end

  def deleted?
    !object.stored.model || object.stored.model.trashed?
  end
end