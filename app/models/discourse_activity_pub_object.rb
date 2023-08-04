# frozen_string_literal: true

class DiscourseActivityPubObject < ActiveRecord::Base
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, -> { unscope(where: :deleted_at) }, polymorphic: true, optional: true
  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"

  belongs_to :reply_to, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'reply_to_id'
  has_many :replies, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'reply_to_id'

  belongs_to :collection, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'collection_id'
  has_many :collection_objects, class_name: "DiscourseActivityPubObject", primary_key: 'ap_id', foreign_key: 'collection_id'
  has_many :collection_activities, through: :collection_objects, source: :activities

  attr_accessor :collection_type
  attr_accessor :collection_actor

  COLLECTION_TYPES = %i(activities objects)

  def url
    if local?
      model&.activity_pub_full_url
    else
      self.read_attribute(:url)
    end
  end

  def ready?(ap_type = nil)
    return true unless local?
    return items.all? { |item| item.ready? } if ap.collection?

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
    if ap.collection?
      items.any? { |item| item.private? }
    else
      activities.any? { |activity| activity.private? }
    end
  end

  def update_from_model
    return unless model && !model.trashed?
    self.content = model.activity_pub_content
    self.save!
  end

  def in_reply_to_post
    reply_to&.model_type == 'Post' && reply_to.model
  end

  def after_deliver
    after_published(Time.now.utc.iso8601)
  end

  def after_scheduled(scheduled_at, activity = nil)
    send_to_collection(:activities, "after_scheduled", scheduled_at) if ap.collection?

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
    send_to_collection(:activities, "after_published", published_at) if ap.collection?

    if model&.respond_to?(:activity_pub_after_publish)
      args = {}
      args[:published_at] = published_at if activity&.ap.create?
      args[:deleted_at] = published_at if activity&.ap.delete?
      args[:updated_at] = published_at if activity&.ap.update?
      model.activity_pub_after_publish(args)
    end
  end

  def items
    return nil unless ap.collection?

    if collection_type == :activities && collection_actor
      collection_activities_announced
    else
      collection_items
    end
  end

  def to
    @to ||= ap.collection? ? public_collection_id : (
      activities.first.present? ? activities.first.to : public_collection_id
    )
  end

  def announce!(actor_id)
    return unless ap.collection?

    DiscourseActivityPubActivity.upsert_all(
      collection_items.map do |item|
        ap_key = SecureRandom.hex(16)
        {
          ap_key: ap_key,
          ap_id: json_ld_id(DiscourseActivityPub::AP::Activity.base_type, ap_key),
          ap_type: DiscourseActivityPub::AP::Activity::Announce.type,
          local: true,
          actor_id: actor_id,
          object_id: item.id,
          object_type: item.class.name,
          visibility: DiscourseActivityPubActivity.visibilities[:public]
        }
      end
    )
    self
  end

  def collection_of(collection_type)
    return nil unless ap.collection? && COLLECTION_TYPES.include?(collection_type)
    @collection_type = collection_type
    self
  end

  protected

  def collection_items
    self.send("collection_#{(collection_type).to_s}")
  end

  def collection_actor
    @collection_actor ||= model&.activity_pub_actor
  end

  def collection_type
    @collection_type ||= :activities
  end

  def send_to_collection(type, method, value)
    self.send("collection_#{type.to_s}").where(published_at: nil).each do |item|
      item.send(method, value)
    end
  end

  def collection_activities_announced
    DiscourseActivityPubActivity.where(
      local: true,
      actor_id: collection_actor.id,
      object_id: collection_items.map(&:id),
      object_type: 'DiscourseActivityPubActivity',
      ap_type: DiscourseActivityPub::AP::Activity::Announce.type
    )
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
