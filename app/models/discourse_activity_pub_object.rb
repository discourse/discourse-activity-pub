# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::IdentifierValidations
  include DiscourseActivityPub::AP::ModelValidations
  include DiscourseActivityPub::AP::ObjectHelpers

  belongs_to :model, -> { unscope(where: :deleted_at) }, polymorphic: true, optional: true
  belongs_to :collection, class_name: "DiscourseActivityPubCollection", foreign_key: "collection_id"

  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"
  has_one :create_activity,
          -> { where(ap_type: DiscourseActivityPub::AP::Activity::Create.type) },
          class_name: "DiscourseActivityPubActivity",
          foreign_key: "object_id"
  has_many :announcements,
           class_name: "DiscourseActivityPubActivity",
           through: :activities,
           source: :announcement
  has_many :likes,
           -> { likes },
           class_name: "DiscourseActivityPubActivity",
           foreign_key: "object_id"

  belongs_to :reply_to,
             class_name: "DiscourseActivityPubObject",
             primary_key: "ap_id",
             foreign_key: "reply_to_id"
  has_many :replies,
           class_name: "DiscourseActivityPubObject",
           primary_key: "ap_id",
           foreign_key: "reply_to_id"

  belongs_to :attributed_to,
             class_name: "DiscourseActivityPubActor",
             primary_key: "ap_id",
             foreign_key: "attributed_to_id"

  def url
    if local?
      model&.activity_pub_full_url
    else
      self.read_attribute(:url)
    end
  end

  def ready?(parent_ap_type = nil)
    return true unless local?
    return false unless model&.activity_pub_enabled

    case parent_ap_type
    when DiscourseActivityPub::AP::Activity::Create.type,
         DiscourseActivityPub::AP::Activity::Update.type,
         DiscourseActivityPub::AP::Activity::Like.type,
         DiscourseActivityPub::AP::Activity::Undo.type,
         DiscourseActivityPub::AP::Activity::Announce.type
      !model_trashed?
    when DiscourseActivityPub::AP::Activity::Delete.type
      model_trashed?
    else
      false
    end
  end

  def private?
    activities.any? { |activity| activity.private? }
  end

  def public?
    !private?
  end

  def publish?
    !model_trashed?
  end

  def model_trashed?
    !model || model.trashed?
  end

  def post?
    model_type == "Post"
  end

  def closest_local_object
    self.local? ? self : reply_to&.closest_local_object
  end

  def in_reply_to_post
    reply_to&.post? && reply_to&.model
  end

  def before_deliver
  end

  def after_deliver(delivered = true)
    if delivered && model.respond_to?(:activity_pub_after_deliver)
      args = { delivered_at: get_delivered_at }
      model.activity_pub_after_deliver(args)
    end
  end

  def after_scheduled(scheduled_at, activity = nil)
    if model.respond_to?(:activity_pub_after_scheduled)
      args = { scheduled_at: scheduled_at }
      if activity&.ap&.create?
        args[:published_at] = nil
        args[:deleted_at] = nil
        args[:updated_at] = nil
      end
      model.activity_pub_after_scheduled(args)
    end
  end

  def after_published(published_at, activity = nil)
    self.update(published_at: published_at)

    if model.respond_to?(:activity_pub_after_publish)
      args = {}
      args[:published_at] = published_at if activity&.ap&.create?
      args[:deleted_at] = published_at if activity&.ap&.delete?
      args[:updated_at] = published_at if activity&.ap&.update?
      model.activity_pub_after_publish(args)
    end
  end

  def context
    self.read_attribute(:context) || collection&.ap_id
  end

  def target
    self.read_attribute(:target) || context
  end

  def audience
    self.read_attribute(:audience) || topic_actor&.ap_id
  end

  def to
    local? && create_activity&.to
  end

  def cc
    local? && create_activity&.cc
  end

  def topic_actor
    model.respond_to?(:activity_pub_topic_actor) ? model.activity_pub_topic_actor : nil
  end

  def attributed_to
    if model&.activity_pub_first_post
      topic_actor
    else
      super
    end
  end

  def likes_collection
    @likes_collection ||=
      begin
        collection =
          DiscourseActivityPubCollection.new(
            ap_id: "#{self.ap_id}#likes",
            ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
            created_at: self.created_at,
            updated_at: self.updated_at,
          )
        collection.items = likes
        collection.context = :likes
        collection
      end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_objects
#
#  id               :bigint           not null, primary key
#  ap_id            :string           not null
#  ap_key           :string
#  ap_type          :string           not null
#  local            :boolean
#  model_id         :integer
#  model_type       :string
#  content          :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  reply_to_id      :string
#  collection_id    :bigint
#  published_at     :datetime
#  url              :string
#  domain           :string
#  name             :string
#  audience         :string
#  context          :string
#  target           :string
#  attributed_to_id :string
#
# Indexes
#
#  index_discourse_activity_pub_objects_on_ap_id  (ap_id) UNIQUE
#  unique_activity_pub_object_models              (model_type,model_id) UNIQUE
#
