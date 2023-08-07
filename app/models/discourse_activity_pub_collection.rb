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

  def private?
    items.any? { |item| item.private? }
  end

  def after_deliver
    @context = :activities
    after_published(Time.now.utc.iso8601)
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
    model ? model.activity_pub_actor : object
  end

  def to
    @to ||= public_collection_id
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
            visibility: DiscourseActivityPubActivity.visibilities[:public],
            collection_id: self.id
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

  protected

  def send_to_collection(method, value)
    items.where(published_at: nil).each do |item|
      item.send(method, value)
    end
  end
end
