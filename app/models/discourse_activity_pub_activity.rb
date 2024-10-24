# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::IdentifierValidations
  include DiscourseActivityPub::AP::ObjectValidations

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  has_one :parent, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"
  has_one :announcement,
          -> { where(ap_type: DiscourseActivityPub::AP::Activity::Announce.type) },
          class_name: "DiscourseActivityPubActivity",
          foreign_key: "object_id"

  validates :actor_id, presence: true
  validate :validate_ap_type,
           if: Proc.new { |a| a.will_save_change_to_ap_type? || a.will_save_change_to_object_type? }

  scope :likes, -> { where(ap_type: DiscourseActivityPub::AP::Activity::Like.type) }

  def ready?(parent_ap_type = nil)
    case object_type
    when "DiscourseActivityPubActivity"
      object&.ready?
    when "DiscourseActivityPubObject"
      object&.ready?(parent_ap_type || ap_type)
    when "DiscourseActivityPubActor"
      object&.ready?
    end
  end

  def publish?
    return false unless ready?
    return true if ap.follow? || ap.response? || ap.undo?
    DiscourseActivityPub.publishing_enabled
  end

  def self.visibilities
    @visibilities ||= Enum.new(private: 1, public: 2)
  end

  def self.default_visibility
    visibilities[column_defaults["visibility"]].to_s
  end

  def public?
    visibility === DiscourseActivityPubActivity.visibilities[:public]
  end

  def private?
    visibility === DiscourseActivityPubActivity.visibilities[:private]
  end

  def base_object
    @base_object ||= find_base_object(object)
  end

  def audience
    base_object&.ap&.object? && base_object.audience
  end

  def to
    return nil unless local?
    return audience if audience
    base_object.ap_id if base_object&.ap&.actor?
  end

  def cc
    return nil unless local?
    result = []
    result << DiscourseActivityPub::JsonLd.public_collection_id if public?

    if base_object&.ap&.object?
      reply_to_audience = base_object.reply_to&.audience
      result << reply_to_audience if reply_to_audience && to != reply_to_audience
    end

    result.present? ? result : nil
  end

  def announce!(actor_id)
    DiscourseActivityPubActivity.find_or_create_by!(
      local: true,
      actor_id: actor_id,
      object_id: self.id,
      object_type: self.class.name,
      ap_type: DiscourseActivityPub::AP::Activity::Announce.type,
      visibility: DiscourseActivityPubActivity.visibilities[:public],
    )
  end

  def before_deliver
    # We have to set "published" on the JSON we deliver
    after_published(Time.now.utc.iso8601, self)
  end

  def after_deliver(delivered = true)
    return unless local?
    return self.destroy! if !delivered && ap.follow?

    if delivered && undo_follow?
      DiscourseActivityPubFollow.where(
        follower_id: actor_id,
        followed_id: object.object.id,
      ).destroy_all
    end

    # We destroy our local follow whether or not our follow rejection was delivered.
    if reject_follow?
      DiscourseActivityPubFollow.where(
        follower_id: object.actor.id,
        followed_id: actor_id,
      ).destroy_all
    end
  end

  def undo_follow?
    ap.undo? && object.ap.follow?
  end

  def reject_follow?
    ap.reject? && object.ap.follow?
  end

  def after_scheduled(scheduled_at, _activity = nil)
    object.after_scheduled(scheduled_at, self) if object.respond_to?(:after_scheduled)
  end

  def after_published(published_at, _activity = nil)
    self.update(published_at: published_at) if !self.published_at
    object.after_published(published_at, self) if object.respond_to?(:after_published)
  end

  protected

  def validate_ap_type
    return unless actor
    object_ap_type = object.respond_to?(:ap_type) ? object.ap_type : nil
    unless actor.can_perform_activity?(ap_type, object_ap_type)
      self.errors.add(
        :ap_type,
        I18n.t(
          "activerecord.errors.models.discourse_activity_pub_activity.attributes.ap_type.invalid",
        ),
      )
    end
  end

  def find_base_object(current_object)
    if current_object.respond_to?(:object) && current_object&.object
      find_base_object(current_object.object)
    else
      current_object
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_activities
#
#  id           :bigint           not null, primary key
#  ap_id        :string           not null
#  ap_key       :string
#  ap_type      :string           not null
#  local        :boolean
#  actor_id     :bigint           not null
#  object_id    :bigint
#  object_type  :string
#  summary      :string
#  published_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  visibility   :integer          default(2)
#
# Indexes
#
#  index_discourse_activity_pub_activities_on_ap_id  (ap_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => discourse_activity_pub_actors.id)
#
