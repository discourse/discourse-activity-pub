# frozen_string_literal: true
class DiscourseActivityPubActor < ActiveRecord::Base
  include DiscourseActivityPub::AP::IdentifierValidations
  include DiscourseActivityPub::AP::ModelValidations
  include DiscourseActivityPub::AP::ObjectHelpers
  include DiscourseActivityPub::WebfingerActorAttributes

  APPLICATION_ACTOR_ID = -1
  APPLICATION_ACTOR_USERNAME = "discourse.internal"
  SERIALIZED_FIELDS = %i[enabled username name default_visibility publication_type post_object_type]
  GROUP_MODELS = %w[Category Tag]

  scope :active, -> { where(model_type: GROUP_MODELS, enabled: true) }

  belongs_to :model, polymorphic: true, optional: true
  belongs_to :category,
             -> do
               includes(:activity_pub_actor).where(
                 discourse_activity_pub_actors: {
                   model_type: "Category",
                 },
               )
             end,
             foreign_key: "model_id",
             optional: true
  belongs_to :tag,
             -> do
               includes(:activity_pub_actor).where(
                 discourse_activity_pub_actors: {
                   model_type: "Tag",
                 },
               )
             end,
             foreign_key: "model_id",
             optional: true
  belongs_to :user,
             -> do
               includes(:activity_pub_actor).where(
                 discourse_activity_pub_actors: {
                   model_type: "User",
                 },
               )
             end,
             foreign_key: "model_id",
             optional: true

  has_one :authorization, class_name: "DiscourseActivityPubAuthorization", foreign_key: "actor_id"
  has_one :authorized_user,
          through: :authorization,
          source: :user,
          foreign_key: "user_id",
          class_name: "User"

  has_many :activities,
           class_name: "DiscourseActivityPubActivity",
           foreign_key: "actor_id",
           dependent: :destroy
  has_many :follow_followers,
           class_name: "DiscourseActivityPubFollow",
           foreign_key: "followed_id",
           dependent: :destroy
  has_many :follow_follows,
           class_name: "DiscourseActivityPubFollow",
           foreign_key: "follower_id",
           dependent: :destroy
  has_many :followers,
           class_name: "DiscourseActivityPubActor",
           through: :follow_followers,
           source: :follower,
           dependent: :destroy
  has_many :follows,
           class_name: "DiscourseActivityPubActor",
           through: :follow_follows,
           source: :followed,
           dependent: :destroy
  has_many :objects,
           class_name: "DiscourseActivityPubObject",
           primary_key: "ap_id",
           foreign_key: "attributed_to_id",
           dependent: :destroy
  has_many :collections,
           class_name: "DiscourseActivityPubCollection",
           primary_key: "ap_id",
           foreign_key: "attributed_to_id",
           dependent: :destroy

  scope :local, -> { where(local: true) }

  validates :username, presence: true, if: :local?
  validate :local_username_uniqueness, if: :local?

  before_save :ensure_keys, if: :local?
  before_save :ensure_inbox_and_outbox, if: :local?

  attr_accessor :followed_at

  def available?
    local? ? true : self.available
  end

  def ready?(parent_ap_type = nil)
    return true if self.id == APPLICATION_ACTOR_ID
    local? ? model.activity_pub_ready? : available?
  end

  def refresh_remote!
    DiscourseActivityPub::AP::Actor.resolve_and_store(ap_id) unless local?
  end

  def keypair
    @keypair ||=
      begin
        return nil unless private_key || public_key
        OpenSSL::PKey::RSA.new(private_key || public_key)
      end
  end

  def following?(actor)
    return false unless actor
    actor.followers.exists?(id: self.id)
  end

  def can_follow?(actor)
    can_perform_activity?(DiscourseActivityPub::AP::Activity::Follow.type, actor.ap_type)
  end

  def can_perform_activity?(activity_ap_type, object_ap_type = nil)
    return false unless ap && activity_ap_type

    activities = ap.can_perform_activity[activity_ap_type.underscore.to_sym]
    activities.present? &&
      (object_ap_type.nil? || activities.include?(object_ap_type.underscore.to_sym))
  end

  def domain
    local? ? DiscourseActivityPub.host : self.read_attribute(:domain)
  end

  def handle
    handle = DiscourseActivityPub::Webfinger::Handle.new(username: username, domain: domain)
    handle.valid? ? handle.to_s : nil
  end

  def url
    if local?
      model ? model.activity_pub_url : DiscourseActivityPub.base_url
    else
      self.ap_id
    end
  end

  def icon_url
    if local?
      model ? model.activity_pub_icon_url : DiscourseActivityPub.icon_url
    else
      self.read_attribute(:icon_url)
    end
  end

  def followers_collection
    @followers_collection ||=
      begin
        collection =
          DiscourseActivityPubCollection.new(
            ap_id: "#{self.ap_id}/followers",
            ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
            created_at: self.created_at,
            updated_at: self.updated_at,
            summary: I18n.t("discourse_activity_pub.actor.followers.summary", actor: username),
          )
        collection.items = followers
        collection.context = :followers
        collection
      end
  end

  def outbox_collection
    @outbox_collection ||=
      begin
        collection =
          DiscourseActivityPubCollection.new(
            ap_id: "#{self.ap_id}/outbox",
            ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
            created_at: self.created_at,
            updated_at: self.updated_at,
            summary: I18n.t("discourse_activity_pub.actor.outbox.summary", actor: username),
          )
        collection.items = activities
        collection.context = :outbox
        collection
      end
  end

  def shared_inbox
    if local?
      model.activity_pub_shared_inbox if model.respond_to?(:activity_pub_shared_inbox)
    else
      self.read_attribute(:shared_inbox)
    end
  end

  def enable!
    self.enabled = true
    save_model_changes
  end

  def disable!
    self.enabled = false
    save_model_changes
  end

  def restore!
    return false if !tombstoned? || !model || model.destroyed?
    restore_tombstoned_objects!
    restore_tombstoned!
  end

  def save_model_changes
    if save!
      model.activity_pub_publish_state
      true
    else
      false
    end
  end

  def tombstone_objects!
    sql = <<~SQL
    UPDATE discourse_activity_pub_objects
    SET ap_former_type = discourse_activity_pub_objects.ap_type,
        ap_type = :ap_type,
        deleted_at = :deleted_at
    WHERE attributed_to_id = :actor_ap_id
    SQL
    DB.exec(
      sql,
      actor_ap_id: self.ap_id,
      ap_type: DiscourseActivityPub::AP::Object::Tombstone.type,
      deleted_at: Time.now.utc.iso8601,
    )

    sql = <<~SQL
    UPDATE discourse_activity_pub_collections
    SET ap_former_type = discourse_activity_pub_collections.ap_type,
        ap_type = :ap_type,
        deleted_at = :deleted_at
    WHERE attributed_to_id = :actor_ap_id
    SQL
    DB.exec(
      sql,
      actor_ap_id: self.ap_id,
      ap_type: DiscourseActivityPub::AP::Object::Tombstone.type,
      deleted_at: Time.now.utc.iso8601,
    )
  end

  def restore_tombstoned_objects!
    sql = <<~SQL
    UPDATE discourse_activity_pub_objects
    SET ap_former_type = null,
        ap_type = COALESCE(discourse_activity_pub_objects.ap_former_type, :default_ap_type),
        deleted_at = null
    WHERE attributed_to_id = :actor_ap_id
    SQL
    DB.exec(
      sql,
      actor_ap_id: self.ap_id,
      default_ap_type: DiscourseActivityPub::AP::Object::Note.type,
    )

    sql = <<~SQL
    UPDATE discourse_activity_pub_collections
    SET ap_former_type = null,
        ap_type = COALESCE(discourse_activity_pub_collections.ap_former_type, :default_ap_type),
        deleted_at = null
    WHERE attributed_to_id = :actor_ap_id
    SQL
    DB.exec(
      sql,
      actor_ap_id: self.ap_id,
      default_ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
    )
  end

  def destroy_objects!
    objects.destroy_all
    collections.destroy_all
  end

  def self.find_by_handle(raw_handle, local: false, refresh: false, types: [])
    handle = DiscourseActivityPub::Webfinger::Handle.new(handle: raw_handle)
    return nil unless handle.valid?
    return nil unless !local || DiscourseActivityPub::URI.local?(handle.domain)

    opts = { username: handle.username }
    opts[:local] = local ? true : [false, nil]
    opts[:domain] = handle.domain if !local
    opts[:ap_type] = types if types.present?
    actor = DiscourseActivityPubActor.find_by(opts)

    actor = resolve_and_store_by_handle(handle.to_s) if (refresh || !actor) && !local

    actor
  end

  def self.find_by_ap_id(ap_id, local: false, refresh: false)
    return nil unless !local || DiscourseActivityPub::URI.local?(ap_id)

    opts = { ap_id: ap_id }
    opts[:local] = local ? true : [false, nil]
    actor = DiscourseActivityPubActor.find_by(opts)

    if (refresh || !actor) && !local
      ap_actor = DiscourseActivityPub::AP::Actor.resolve_and_store(ap_id)
      actor = ap_actor.stored if ap_actor
    end

    actor
  end

  def self.find_by_id_or_handle(id_or_handle, local: true, refresh: false)
    if id_or_handle.include?("@")
      find_by_handle(id_or_handle, local: local, refresh: refresh)
    elsif DiscourseActivityPub::URI.valid_url?(id_or_handle)
      find_by_ap_id(id_or_handle, local: local, refresh: refresh)
    else
      find_by(id: id_or_handle)
    end
  end

  def self.resolve_and_store_by_handle(raw_handle)
    ap_id = DiscourseActivityPub::Webfinger.resolve_id_by_handle(raw_handle)
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
    !self.where(sql, args).exists?
  end

  # Equivalent of mastodon/mastodon/app/models/concerns/account_finder_concern.rb#representative
  def self.application
    DiscourseActivityPubActor.find(DiscourseActivityPubActor::APPLICATION_ACTOR_ID)
  rescue ActiveRecord::RecordNotFound
    DiscourseActivityPubActor.create!(
      id: DiscourseActivityPubActor::APPLICATION_ACTOR_ID,
      ap_type: DiscourseActivityPub::AP::Actor::Application.type,
      username: DiscourseActivityPubActor::APPLICATION_ACTOR_USERNAME,
      local: true,
    )
  end

  def ensure_keys
    return unless local? && private_key.blank? && public_key.blank?

    keypair = OpenSSL::PKey::RSA.new(2048)
    self.private_key = keypair.to_pem
    self.public_key = keypair.public_key.to_pem
  end

  def ensure_inbox_and_outbox
    return unless local?

    self.inbox = "#{self.ap_id}/inbox" if !self.inbox || self.inbox.exclude?(self.ap_key)
    self.outbox = "#{self.ap_id}/outbox" if !self.outbox || self.outbox.exclude?(self.ap_key)
  end

  def local_username_uniqueness
    if will_save_change_to_username?
      existing =
        DiscourseActivityPubActor
          .local
          .where.not(id: self.id)
          .where(username: self.username)
          .exists?
      errors.add(:username, "Username taken by local actor") if existing
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_actors
#
#  id                 :bigint           not null, primary key
#  ap_id              :string           not null
#  ap_key             :string
#  ap_type            :string           not null
#  domain             :string
#  local              :boolean
#  available          :boolean          default(TRUE)
#  inbox              :string
#  outbox             :string
#  username           :string
#  name               :string
#  model_id           :integer
#  model_type         :string
#  private_key        :text
#  public_key         :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  icon_url           :string
#  shared_inbox       :string
#  enabled            :boolean
#  default_visibility :string
#  publication_type   :string
#  post_object_type   :string
#  deleted_at         :datetime
#  ap_former_type     :string
#
# Indexes
#
#  index_discourse_activity_pub_actors_on_ap_id  (ap_id) UNIQUE
#  unique_activity_pub_actor_models              (model_type,model_id) UNIQUE
#
