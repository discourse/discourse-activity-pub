# frozen_string_literal: true
class DiscourseActivityPubActivity < ActiveRecord::Base
  include DiscourseActivityPub::AP::ActivityValidations

  belongs_to :actor, class_name: "DiscourseActivityPubActor"
  belongs_to :object, polymorphic: true

  after_create :deliver_composition, if: Proc.new { ap&.composition? }

  def create?
    ap_type === DiscourseActivityPub::AP::Activity::Create.type
  end

  def delete?
    ap_type === DiscourseActivityPub::AP::Activity::Delete.type
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

  def deliver_composition
    return unless ap&.composition?

    actor.followers.each do |follower|
      opts = {
        to_actor_id: follower.id
      }

      if ap.type != DiscourseActivityPub::AP::Activity::Delete.type
        opts[:delay] = SiteSetting.activity_pub_delivery_delay_minutes.to_i
      end

      deliver(**opts)
    end
  end

  def deliver(to_actor_id: nil, delay: nil)
    return unless to_actor_id

    args = {
      activity_id: self.id,
      from_actor_id: actor.id,
      to_actor_id: to_actor_id
    }

    Jobs.cancel_scheduled_job(:discourse_activity_pub_deliver, args)

    if delay
      Jobs.enqueue_in(delay.minutes, :discourse_activity_pub_deliver, args)
      scheduled_at = (Time.now.utc + delay.minutes).iso8601
    else
      Jobs.enqueue(:discourse_activity_pub_deliver, args)
      scheduled_at = Time.now.utc.iso8601
    end

    after_scheduled(scheduled_at)
  end

  def after_scheduled(scheduled_at)
    if self.object&.respond_to?(:model) && self.object.model&.respond_to?(:activity_pub_after_scheduled)
      args = {
        scheduled_at: scheduled_at
      }
      self.object.model.activity_pub_after_scheduled(args)
    end
  end

  def after_deliver
    if !self.published_at
      published_at = Time.now.utc.iso8601
      self.update(published_at: published_at)

      if self.object.local && self.object.model&.respond_to?(:activity_pub_after_publish)
        args = {}
        args[:published_at] = published_at if create?
        args[:deleted_at] = published_at if delete?
        args[:updated_at] = published_at if update?
        self.object.model.activity_pub_after_publish(args)
      end
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
#
# Indexes
#
#  index_discourse_activity_pub_activities_on_ap_id  (ap_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => discourse_activity_pub_actors.id)
#
