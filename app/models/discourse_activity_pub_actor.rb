# frozen_string_literal: true
class DiscourseActivityPubActor < ActiveRecord::Base
  include DiscourseActivityPub::AP::IdentifierValidations
  include DiscourseActivityPub::AP::ModelValidations
  include DiscourseActivityPub::WebfingerActorAttributes

  belongs_to :model, polymorphic: true, optional: true
  belongs_to :user, -> { where(discourse_activity_pub_actors: { model_type: 'User' }) }, foreign_key: 'model_id', optional: true

  has_many :activities, class_name: "DiscourseActivityPubActivity", foreign_key: "actor_id", dependent: :destroy
  has_many :follow_followers, class_name: "DiscourseActivityPubFollow", foreign_key: "followed_id", dependent: :destroy
  has_many :follow_follows, class_name: "DiscourseActivityPubFollow", foreign_key: "follower_id", dependent: :destroy
  has_many :followers, class_name: "DiscourseActivityPubActor", through: :follow_followers, source: :follower, dependent: :destroy
  has_many :follows, class_name: "DiscourseActivityPubActor", through: :follow_follows, source: :followed, dependent: :destroy

  validates :username, presence: true, if: :local?
  validate :local_username_uniqueness, if: :local?

  before_save :ensure_keys, if: :local?
  before_save :ensure_inbox_and_outbox, if: :local?

  attr_accessor :followed_at

  def available?
    local? ? true : self.available
  end

  def ready?(parent_ap_type = nil)
    local? ? model.activity_pub_ready? : available?
  end

  def remote?
    !local?
  end

  def refresh_remote!
    DiscourseActivityPub::AP::Actor.resolve_and_store(ap_id) unless local?
  end

  def keypair
    @keypair ||= begin
      return nil unless private_key || public_key
      OpenSSL::PKey::RSA.new(private_key || public_key)
    end
  end

  def following?(actor)
    return false unless actor
    actor.followers.exists?(id: self.id)
  end

  def can_follow?(actor)
    can_perform_activity?(
      DiscourseActivityPub::AP::Activity::Follow.type,
      actor.ap_type
    )
  end

  def can_perform_activity?(activity_ap_type, object_ap_type = nil)
    return false unless ap && activity_ap_type

    activities = ap.can_perform_activity[activity_ap_type.underscore.to_sym]
    activities.present? && (
      object_ap_type.nil? || activities.include?(object_ap_type.underscore.to_sym)
    )
  end

  def domain
    local? ? DiscourseActivityPub.host : self.read_attribute(:domain)
  end

  def handle
    handle = DiscourseActivityPub::Webfinger::Handle.new(username: username, domain: domain)
    handle.valid? ? handle.to_s : nil
  end

  def url
    local? ? model&.activity_pub_url : self.ap_id
  end

  def icon_url
    if local?
      model.activity_pub_icon_url
    else
      self.read_attribute(:icon_url)
    end
  end

  def followers_collection
    @followers_collection ||= begin
      collection = DiscourseActivityPubCollection.new(
        ap_id: "#{self.ap_id}#followers",
        ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
        created_at: self.created_at,
        updated_at: self.updated_at,
        summary: I18n.t("discourse_activity_pub.actor.followers.summary", actor: username)
      )
      collection.items = followers
      collection.context = :followers
      collection
    end
  end

  def outbox_collection
    @outbox_collection ||= begin
      collection = DiscourseActivityPubCollection.new(
        ap_id: "#{self.ap_id}#activities",
        ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
        created_at: self.created_at,
        updated_at: self.updated_at,
        summary: I18n.t("discourse_activity_pub.actor.outbox.summary", actor: username)
      )
      collection.items = activities
      collection.context = :outbox
      collection
    end
  end

  def shared_inbox
    if local?
      model.activity_pub_shared_inbox if model&.respond_to?(:activity_pub_shared_inbox)
    else
      self.read_attribute(:shared_inbox)
    end
  end

  def self.ensure_for(model)
    if model.activity_pub_enabled
      actor = model.activity_pub_actor ||
        model.build_activity_pub_actor(
          username: model.activity_pub_username,
          local: true
        )
      actor.name = model.activity_pub_name

      if actor.new_record? || actor.changed?
        actor.save!
        model.activity_pub_publish_state
      end
    end
  end

  def self.find_by_handle(raw_handle, local: false, refresh: false)
    handle = DiscourseActivityPub::Webfinger::Handle.new(handle: raw_handle)
    return nil unless handle.valid?
    return nil unless !local || DiscourseActivityPub::URI.local?(handle.domain)

    unless refresh
      opts = { username: handle.username }
      opts[:domain] = handle.domain if !local
      actor = DiscourseActivityPubActor.find_by(opts)
      return actor if actor
    end

    return resolve_and_store(handle.to_s) if !local

    nil
  end

  def self.resolve_and_store(raw_handle)
    ap_id = DiscourseActivityPub::Webfinger.find_id_by_handle(raw_handle)
    return nil unless ap_id

    ap_actor = DiscourseActivityPub::AP::Actor.resolve_and_store(ap_id)
    ap_actor&.stored
  end

  def self.username_unique?(username, model_id: nil, local: true)
    sql = "username = :username"
    sql += " AND model_id <> :model_id" if model_id
    sql += " AND local IS TRUE" if local
    args = { username: username }
    args[:model_id] = model_id if model_id
    self.where(sql, args).exists?
  end

  protected

  def ensure_keys
    return unless local? && private_key.blank? && public_key.blank?

    keypair = OpenSSL::PKey::RSA.new(2048)
    self.private_key = keypair.to_pem
    self.public_key  = keypair.public_key.to_pem

    save!
  end

  def ensure_inbox_and_outbox
    self.inbox = "#{self.ap_id}/inbox" if !self.inbox
    self.outbox = "#{self.ap_id}/outbox" if !self.outbox
  end

  def local_username_uniqueness
    if will_save_change_to_username?
      existing = DiscourseActivityPubActor
        .where.not(id: self.id)
        .where(local: true, username: self.username)
        .exists?
      errors.add(:username, "Username taken by local actor") if existing
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_actors
#
#  id          :bigint           not null, primary key
#  ap_id       :string           not null
#  ap_key      :string
#  ap_type     :string           not null
#  domain      :string
#  local       :boolean
#  available   :boolean          default(TRUE)
#  inbox       :string
#  outbox      :string
#  username    :string
#  name        :string
#  model_id    :integer
#  model_type  :string
#  private_key :text
#  public_key  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  icon_url    :string
#
# Indexes
#
#  index_discourse_activity_pub_actors_on_ap_id  (ap_id)
#
