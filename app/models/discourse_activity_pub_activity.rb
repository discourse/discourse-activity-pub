# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::ActivityValidations

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true
  has_one :parent, class_name: "DiscourseActivityPubActivity", foreign_key: "object_id"

  def ready?
    case object_type
    when "DiscourseActivityPubActivity"
      object&.ready?
    when "DiscourseActivityPubObject"
      object&.ready?(ap_type)
    when "DiscourseActivityPubActor"
      object&.ready?
    end
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

  def to
    if public?
      public_collection_id
    else
      primary_actor.followers_collection.ap_id
    end
  end

  def primary_actor
    if parent && parent.parent && parent.parent.ap.activity?
      parent.parent.actor
    elsif parent && parent.ap.activity?
      parent.actor
    else
      actor
    end
  end

  def announce!(actor_id)
    DiscourseActivityPubActivity.create!(
      local: true,
      actor_id: actor_id,
      object_id: self.id,
      object_type: self.class.name,
      ap_type: DiscourseActivityPub::AP::Activity::Announce.type,
      visibility: DiscourseActivityPubActivity.visibilities[:public]
    )
  end

  def after_deliver
    after_published(Time.now.utc.iso8601, self)
  end

  def after_scheduled(scheduled_at, _activity = nil)
    object.after_scheduled(scheduled_at, self) if object.respond_to?(:after_scheduled)
  end

  def after_published(published_at, _activity = nil)
    self.update(published_at: published_at) if !self.published_at
    object.after_published(published_at, self) if object.respond_to?(:after_published)
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
#  actor_id     :integer          not null
#  object_id    :string
#  object_type  :string
#  summary      :string
#  published_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  visibility   :integer          default(2)
#
# Indexes
#
#  index_discourse_activity_pub_activities_on_ap_id  (ap_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => discourse_activity_pub_actors.id)
#
