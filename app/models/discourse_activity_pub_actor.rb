# frozen_string_literal: true
class DiscourseActivityPubActor < ActiveRecord::Base
  belongs_to :model, polymorphic: true

  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "actor_id"
  has_many :followers, class_name: "DiscourseActivityPubFollow", foreign_key: "followed_id"
  has_many :follows, class_name: "DiscourseActivityPubFollow", foreign_key: "follower_id"

  validates :uid, presence: true, uniqueness: true
  validates :domain, presence: true
  validates :ap_type, presence: true

  validate :validate_model_type, if: :will_save_change_to_model_type?

  def following?(model)
    model.activity_pub_followers.exists?(follower_id: self.id)
  end

  def ap_actor
    @ap_actor ||= DiscourseActivityPub::AP::Actor.factory({ type: ap_type })
  end

  def can_belong_to?(model_type)
    return false unless ap_actor && model_type

    ap_actor.can_belong_to.include?(model_type.downcase.to_sym)
  end

  def can_perform_activity?(activity_type, object_type = nil)
    return false unless ap_actor && activity_type

    activities = ap_actor.can_perform_activity[activity_type.downcase.to_sym]
    activities.present? && (
      object_type.nil? || activities.include?(object_type.downcase.to_sym)
    )
  end

  private

  def validate_model_type
    @ap_actor = nil

    unless can_belong_to?(model_type)
      self.errors.add(
        :ap_type,
        I18n.t("activerecord.errors.models.discourse_activity_pub_actor.attributes.ap_type.invalid")
      )
    end
  end
end

# == Schema Information
#
# Table name: activity_pub_actors
#
#  id                 :bigint           not null, primary key
#  uid                :string           not null
#  preferred_username :string           not null
#  name               :string
#  inbox              :string
#  outbox             :string
#  domain             :string           not null
#  ap_type         :string           not null
#  object_type        :string
#  object_id          :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_activity_pub_actors_on_object  (object_type,object_id)
#  index_activity_pub_actors_on_uid     (uid)
#
