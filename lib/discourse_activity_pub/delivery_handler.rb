# frozen_string_literal: true
module DiscourseActivityPub
  class DeliveryHandler
    attr_reader :actor,
                :object,
                :scheduled_at

    def initialize(actor, object)
      @actor = actor
      @object = object
    end

    def perform(delay: 0)
      return false unless can_deliver?
      return nil unless recipients.present?
      schedule_deliveries(delay)
      after_scheduled
      object
    end

    def self.perform(actor, object, delay = 0)
      new(actor, object).perform(delay: delay)
    end

    protected

    def can_deliver?
      return log_failure("delivery actor not ready") unless actor&.ready?
      return log_failure("object not ready") unless object&.ready?
      true
    end

    def recipients
      @recipients ||= actor.followers
    end

    def schedule_deliveries(delay = nil)
      recipients.each do |actor|
        opts = {
          to_actor_id: actor.id,
        }
        opts[:delay] = delay unless delay.nil?
        schedule_delivery(**opts)
      end
    end

    def schedule_delivery(to_actor_id: nil, delay: nil)
      return unless to_actor_id

      args = {
        object_id: object.id,
        object_type: object.class.name,
        from_actor_id: actor.id,
        to_actor_id: to_actor_id
      }

      Jobs.cancel_scheduled_job(:discourse_activity_pub_deliver, args)

      if delay
        Jobs.enqueue_in(delay.minutes, :discourse_activity_pub_deliver, args)
        @scheduled_at = (Time.now.utc + delay.minutes).iso8601
      else
        Jobs.enqueue(:discourse_activity_pub_deliver, args)
        @scheduled_at = Time.now.utc.iso8601
      end
    end

    def after_scheduled
      object.after_scheduled(scheduled_at) if object.respond_to?(:after_scheduled)
    end

    def log_failure(message)
      return false unless SiteSetting.activity_pub_verbose_logging
      prefix = "#{actor.ap_id} failed to schedule #{object&.ap_id} for delivery"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{message}")
      false
    end
  end
end