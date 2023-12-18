# frozen_string_literal: true

class DiscourseActivityPubCollection < ActiveRecord::Base
  include DiscourseActivityPub::AP::IdentifierValidations
  include DiscourseActivityPub::AP::ModelValidations

  belongs_to :model, -> { unscope(where: :deleted_at) }, polymorphic: true, optional: true

  has_many :objects, class_name: "DiscourseActivityPubObject", foreign_key: "collection_id"
  has_many :activities, class_name: "DiscourseActivityPubActivity", through: :objects
  has_many :announcements, class_name: "DiscourseActivityPubActivity", through: :objects, source: :announcements

  attr_accessor :items
  attr_accessor :context
  attr_accessor :to

  def url
    model&.activity_pub_full_url
  end

  def ready?
    items.all? { |item| item.ready? }
  end

  def publish?
    items.all? { |item| item.publish? }
  end

  def private?
    items.any? { |item| item.respond_to?(:private) && item.private? }
  end

  def public?
    !private?
  end

  def before_deliver
    @context = :activities
    after_published(Time.now.utc.iso8601)
  end

  def after_deliver(delivered = true)
  end

  def after_scheduled(scheduled_at, activity = nil)
    @context = :activities
    send_to_collection("after_scheduled", scheduled_at)
  end

  def after_published(published_at, activity = nil)
    self.update(published_at: published_at)
    send_to_collection("after_published", published_at)
  end

  def actor
    model&.activity_pub_actor
  end

  def audience
    self.read_attribute(:audience) || actor&.ap_id
  end

  def to
    audience
  end

  def cc
    public? ? DiscourseActivityPub::JsonLd.public_collection_id : nil
  end

  def items
    case context
    when :announcement
      announcements
    when :activities
      activities
    when :objects
      objects
    when :outbox
      @items
    when :followers
      @items
    when :follows
      @items
    when :likes
      @items
    else
      []
    end
  end

  def announce!(actor_id)
    DiscourseActivityPubActivity.upsert_all(
      activities
        .where
        .not(ap_type: DiscourseActivityPub::AP::Activity::Announce.type)
        .map do |item|
          ap_key = generate_key
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
  end

  def announcement
    announcements_collection
  end

  def announcements_collection
    @context = :announcement
    self
  end

  def activities_collection
    @context = :activities
    self
  end

  def objects_collection
    @context = :objects
    self
  end

  def contributors(local: nil)
    # Contributors are added as recipients of the collection's activities.
    # See activity_pub_delivery_recipients in app/models/concerns/discourse_activity_pub/ap/model_callbacks.rb
    # See also lib/discourse_activity_pub/activity_forwarder.rb
    objects.each_with_object([]) do |object, result|
      actor = object.attributed_to
      result << actor if actor && (local.nil? || actor.local? == local)
    end
  end

  protected

  def send_to_collection(method, value)
    items.where(published_at: nil).each do |item|
      item.send(method, value)
    end
  end
end

# == Schema Information
#
# Table name: discourse_activity_pub_collections
#
#  id           :bigint           not null, primary key
#  ap_id        :string           not null
#  ap_key       :string
#  ap_type      :string           not null
#  local        :boolean
#  model_id     :integer
#  model_type   :string
#  summary      :string
#  published_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  name         :string
#
# Indexes
#
#  index_discourse_activity_pub_collections_on_ap_id  (ap_id)
#
