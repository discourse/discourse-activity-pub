# frozen_string_literal: true

class DiscourseActivityPub::AP::ObjectSerializer < ActiveModel::Serializer
  attributes :id,
             :type,
             :audience,
             :to,
             :cc,
             :published,
             :updated,
             :url,
             :attributedTo,
             :name,
             :summary,
             :context

  def attributes(*args)
    hash = super
    hash["@context"] = DiscourseActivityPub::JsonLd::ACTIVITY_STREAMS_CONTEXT
    hash
  end

  def include_id?
    object.id.present?
  end

  def include_context?
    object.context.present?
  end

  def include_audience?
    object.audience.present?
  end

  def include_to?
    object.to.present?
  end

  def include_cc?
    object.cc.present?
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
    object.attributed_to.id
  end

  def include_attributedTo?
    object.attributed_to.present?
  end

  def include_name?
    object.name.present?
  end

  def include_summary?
    object.summary.present?
  end
end
