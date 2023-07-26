# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::ActivityValidations

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  attr_accessor :to

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

  def update?
    ap_type === DiscourseActivityPub::AP::Activity::Update.type
  end

  def ready?
    case object_type
    when "DiscourseActivityPubActivity"
      object.ready?
    when "DiscourseActivityPubObject"
      object.ready?(ap_type)
    when "DiscourseActivityPubActor"
      object.ready?
    end
  end

  def address!(to_actor = nil)
    addressed_to = public? ? public_collection_id : (
      to_actor ? to_actor.ap_id : actor.followers.map(&:ap_id)
    )
    @to = addressed_to
    object.to = addressed_to
    object.object.to = addressed_to if object.respond_to?(:object)
  end

  def after_scheduled(scheduled_at)
    if object_model&.respond_to?(:activity_pub_after_scheduled)
      args = {
        scheduled_at: scheduled_at
      }
      if ap.create?
        args[:published_at] = nil
        args[:deleted_at] = nil
        args[:updated_at] = nil
      end
      object_model.activity_pub_after_scheduled(args)
    end
  end

  def after_deliver
    if !self.published_at
      published_at = Time.now.utc.iso8601
      self.class.set_published_at(self, published_at)
      if self.object.is_a?(DiscourseActivityPubActivity)
        self.class.set_published_at(object, published_at)
      end
    end
  end

  def object_model
    self.object&.respond_to?(:model) && self.object.model
  end

  def self.set_published_at(activity, published_at)
    activity.update(published_at: published_at)

    if activity.object.local && activity.object_model&.respond_to?(:activity_pub_after_publish)
      args = {}
      args[:published_at] = published_at if activity.ap.create?
      args[:deleted_at] = published_at if activity.ap.delete?
      args[:updated_at] = published_at if activity.ap.update?
      activity.object_model.activity_pub_after_publish(args)
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
