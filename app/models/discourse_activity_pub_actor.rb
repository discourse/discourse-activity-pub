# frozen_string_literal: true
class DiscourseActivityPubActor < ActiveRecord::Base
  include DiscourseActivityPub::AP::ModelValidations
  include DiscourseActivityPub::WebfingerActorAttributes

  belongs_to :model, polymorphic: true, optional: true

  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "actor_id"
  has_many :follow_followers, class_name: "DiscourseActivityPubFollow", foreign_key: "followed_id"
  has_many :follow_follows, class_name: "DiscourseActivityPubFollow", foreign_key: "follower_id"
  has_many :followers, class_name: "DiscourseActivityPubActor", through: :follow_followers, source: :follower
  has_many :follows, class_name: "DiscourseActivityPubActor", through: :follow_follows, source: :followed

  validates :domain, presence: true

  def following?(model)
    model.activity_pub_followers.exists?(id: self.id)
  end

  def can_perform_activity?(activity_ap_type, object_ap_type = nil)
    return false unless ap && activity_ap_type

    activities = ap.can_perform_activity[activity_ap_type.downcase.to_sym]
    activities.present? && (
      object_ap_type.nil? || activities.include?(object_ap_type.downcase.to_sym)
    )
  end

  def self.ensure_for(model)
    if model.activity_pub_enabled && !model.activity_pub_actor
      model.build_activity_pub_actor(domain: Discourse.current_hostname)
      model.save!
      model.activity_pub_publish_state
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_actors
#
#  id                 :bigint           not null, primary key
#  uid                :string           not null
#  domain             :string           not null
#  ap_type            :string           not null
#  inbox              :string
#  outbox             :string
#  preferred_username :string
#  name               :string
#  model_id           :integer
#  model_type         :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_discourse_activity_pub_actors_on_uid  (uid)
#
