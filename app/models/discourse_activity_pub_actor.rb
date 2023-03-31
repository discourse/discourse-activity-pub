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

  validates :username, presence: true, uniqueness: true, if: :local

  before_save :ensure_keys, if: :local

  def refresh_remote!
    DiscourseActivityPub::AP::Actor.resolve_and_store(ap_id, stored: true) unless local?
  end

  def keypair
    @keypair ||= begin
      return nil unless private_key || public_key
      OpenSSL::PKey::RSA.new(private_key || public_key)
    end
  end

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
      model.build_activity_pub_actor(username: model.activity_pub_username, local: true)
      model.save!
      model.activity_pub_publish_state
    end
  end

  def self.find_by_handle(handle, local: false)
    username, domain = handle.split('@')
    return nil unless !local || domain === Discourse.current_hostname

    opts = { username: username }
    opts[:domain] = domain if !local

    DiscourseActivityPubActor.find_by(opts)
  end

  protected

  def ensure_keys
    return unless local && private_key.blank? && public_key.blank?

    keypair = OpenSSL::PKey::RSA.new(2048)
    self.private_key = keypair.to_pem
    self.public_key  = keypair.public_key.to_pem

    save!
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_actors
#
#  id         :bigint           not null, primary key
#  ap_id      :string           not null
#  ap_key     :string
#  ap_type    :string           not null
#  domain     :string
#  local      :boolean
#  inbox      :string
#  outbox     :string
#  username   :string
#  name       :string
#  model_id   :integer
#  model_type :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_discourse_activity_pub_actors_on_ap_id  (ap_id)
#
