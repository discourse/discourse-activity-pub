# frozen_string_literal: true

class DiscourseActivityPub::AP::ObjectSerializer < ActiveModel::Serializer
  attributes :id,
             :type,
             :audience,
             :published,
             :updated,
             :url,
             :attributedTo

  def attributes(*args)
    hash = super
    hash["@context"] = context
    hash
  end

  def context
    object.context
  end

  def include_audience?
    object.audience.present?
  end

  def include_published?
    object.published.present?
  end

  def include_updated?
    object.updated.present?
  end

  def include_url?
    object.url.present?
  end

  def attributedTo
    object.attributed_to
  end

  def include_attributedTo?
    object.attributed_to.present?
  end
end