# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  OBJECT_TYPES = %w(DiscourseActivityPubActivity DiscourseActivityPubActor)

  validates :ap_type, presence: true
  validates :actor_id, presence: true
  validates :object_id, presence: true
  validates :object_type, presence: true

  validate :validate_object_type, if: :will_save_change_to_object_type?
  validate :validate_ap_type,
           if: Proc.new { |t| t.will_save_change_to_ap_type? || t.will_save_change_to_object_type? }

  before_create :ensure_uid

  def ensure_uid
    self.uid = DiscourseActivityPub::JsonLd.generate_activity_id(actor, ap_type) if !self.uid
  end

  private

  def validate_object_type
    unless OBJECT_TYPES.include?(object_type)
      self.errors.add(
        :object_type,
        I18n.t("activerecord.errors.models.discourse_activity_pub_activity.attributes.object_type.invalid")
      )
    end
  end

  def validate_ap_type
    return unless actor

    object_ap_type = object&.respond_to?(:ap_type) ? object.ap_type : nil

    unless actor.can_perform_activity?(ap_type, object_ap_type)
      self.errors.add(
        :ap_type,
        I18n.t("activerecord.errors.models.discourse_activity_pub_activity.attributes.ap_type.invalid")
      )
    end
  end
end