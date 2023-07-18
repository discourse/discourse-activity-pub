# frozen_string_literal: true

class DiscourseActivityPub::AP::Object::ArticleSerializer < DiscourseActivityPub::AP::ObjectSerializer
  attributes :content,
             :url,
             :updated

  def include_content?
    object.content.present? && !deleted?
  end

  def include_url?
    object.stored.local? && !deleted?
  end

  def include_updated?
    object.updated.present?
  end

  def deleted?
    !object.stored.model || object.stored.model.trashed?
  end
end