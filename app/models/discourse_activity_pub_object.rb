# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::IdentifierValidations
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, -> { unscope(where: :deleted_at) }, polymorphic: true, optional: true
  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"
  has_many :announcements, class_name: "DiscourseActivityPubActivity", through: :activities, source: :announcement

  belongs_to :reply_to, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'reply_to_id'
  has_many :replies, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'reply_to_id'

  def url
    if local?
      model&.activity_pub_full_url
    else
      self.read_attribute(:url)
    end
  end

  def ready?(ap_type = nil)
    return true unless local?

    case ap_type
    when DiscourseActivityPub::AP::Activity::Create.type, DiscourseActivityPub::AP::Activity::Update.type
      !!model && !model.trashed?
    when DiscourseActivityPub::AP::Activity::Delete.type
      !model || model.trashed?
    else
      false
    end
  end

  def private?
    activities.any? { |activity| activity.private? }
  end

  def in_reply_to_post
    reply_to&.model_type == 'Post' && reply_to.model
  end

  def after_deliver
    after_published(Time.now.utc.iso8601)
  end

  def after_scheduled(scheduled_at, activity = nil)
    if model&.respond_to?(:activity_pub_after_scheduled)
      args = {
        scheduled_at: scheduled_at
      }
      if activity&.ap.create?
        args[:published_at] = nil
        args[:deleted_at] = nil
        args[:updated_at] = nil
      end
      model.activity_pub_after_scheduled(args)
    end
  end

  def after_published(published_at, activity = nil)
    self.update(published_at: published_at)

    if model&.respond_to?(:activity_pub_after_publish)
      args = {}
      args[:published_at] = published_at if activity&.ap.create?
      args[:deleted_at] = published_at if activity&.ap.delete?
      args[:updated_at] = published_at if activity&.ap.update?
      model.activity_pub_after_publish(args)
    end
  end

  def to
    @to ||= activities.first.present? ? activities.first.to : public_collection_id
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_objects
#
#  id           :bigint           not null, primary key
#  ap_id        :string           not null
#  ap_key       :string
#  ap_type      :string           not null
#  local        :boolean
#  model_id     :integer
#  model_type   :string
#  content      :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  reply_to_id  :string
#  published_at :datetime
#  url          :string
#
# Indexes
#
#  index_discourse_activity_pub_objects_on_ap_id  (ap_id)
#
