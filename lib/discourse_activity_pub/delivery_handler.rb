# frozen_string_literal: true
module DiscourseActivityPub
  class DeliveryHandler
    attr_reader :activity,
                :delivery_actor,
                :delivery_activity

    def initialize(delivery_actor, activity)
      @delivery_actor = delivery_actor
      @activity = activity
    end

    def perform(delay: 0)
      return false unless can_deliver?
      return nil unless recipient_actors.present?
      set_delivery_activity
      deliver_to_recipients(delay)
      activity
    end

    def self.perform(delivery_actor, activity, delay = 0)
      new(delivery_actor, activity).perform(delay: delay)
    end

    protected

    def can_deliver?
      return log_failure("delivery actor not ready") unless delivery_actor&.ready?
      return log_failure("activity not ready") unless activity&.ready?
      return log_failure("can't announce private activities") if announcing? && activity.private?
      true
    end

    def announcing?
      # If an actor is delivering activities they didn't perform they announce (share) them.
      # See further https://codeberg.org/fediverse/fep/src/branch/main/fep/1b12/fep-1b12.md#the-announce-activity
      @announcing ||= delivery_actor.id != activity.actor.id
    end

    def recipient_actors
      @recipient_actors ||= delivery_actor.followers
    end

    def set_delivery_activity
      @delivery_activity = if announcing?
        begin
          DiscourseActivityPubActivity.create!(
            local: true,
            actor_id: delivery_actor.id,
            object_id: activity.id,
            object_type: activity.class.name,
            ap_type: AP::Activity::Announce.type,
            visibility: DiscourseActivityPubActivity.visibilities[:public]
          )
        rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          log_failure(e.message)
        end
      else
        activity
      end
    end

    def deliver_to_recipients(delay = nil)
      recipient_actors.each do |actor|
        opts = {
          to_actor_id: actor.id,
        }
        opts[:delay] = delay unless delay.nil?
        deliver(**opts)
      end
    end

    def deliver(to_actor_id: nil, delay: nil)
      return unless to_actor_id

      args = {
        activity_id: delivery_activity.id,
        from_actor_id: delivery_actor.id,
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

      activity.after_scheduled(scheduled_at)
    end

    def log_failure(message)
      return false unless SiteSetting.activity_pub_verbose_logging

      prefix = "#{delivery_actor.ap_id} failed to schedule #{activity&.ap_id} for delivery"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{message}")
      false
    end
  end
end