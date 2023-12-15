# frozen_string_literal: true
module DiscourseActivityPub
  class DeliveryHandler
    attr_reader :actor,
                :object,
                :recipient_ids,
                :scheduled_at

    def initialize(actor: nil, object: nil, recipient_ids: [])
      @actor = actor
      @object = object
      @recipient_ids = recipient_ids
    end

    def perform(delay: 0, skip_after_scheduled: false)
      return false unless can_deliver?
      schedule_deliveries(delay)
      after_scheduled unless skip_after_scheduled
      object
    end

    def self.perform(actor: nil, object: nil, recipient_ids: [], delay: 0, skip_after_scheduled: false)
      klass = new(actor: actor, object: object, recipient_ids: recipient_ids)
      klass.perform(delay: delay, skip_after_scheduled: skip_after_scheduled)
    end

    protected

    def can_deliver?
      return log_failure("delivery actor not ready") unless actor&.ready?
      return log_failure("object cant be published") unless object&.publish?
      return log_failure("no recipients") if recipients.none?
      true
    end

    def recipients
      @recipients ||= DiscourseActivityPubActor.where(id: recipient_ids).to_a
    end

    def schedule_deliveries(delay = nil)
      recipients
        .uniq { |actor| actor.id }
        .group_by(&:shared_inbox)
        .each do |shared_inbox, actors|
          if shared_inbox
            opts = {
              send_to: shared_inbox,
            }
            opts[:delay] = delay unless delay.nil?
            schedule_delivery(**opts)
          else
            # Recipient Actor does not have a shared inbox.
            actors.each do |actor|
              opts = {
                send_to: actor.inbox
              }
              opts[:delay] = delay unless delay.nil?
              schedule_delivery(**opts)
            end
          end
        end
    end

    def schedule_delivery(send_to: nil, delay: nil)
      return unless send_to.present?

      if !Rails.env.test? && ENV['DISCOURSE_ACTIVITY_PUB_DELIVERY_DELAY'].present?
        delay = ENV['DISCOURSE_ACTIVITY_PUB_DELIVERY_DELAY'].to_i
      end

      args = {
        from_actor_id: actor.id,
        send_to: send_to,
        object_id: object.id,
        object_type: object.class.name
      }

      Jobs.cancel_scheduled_job(:discourse_activity_pub_deliver, args)

      if delay
        Jobs.enqueue_in(delay.to_i.minutes, :discourse_activity_pub_deliver, args)
        @scheduled_at = (Time.now.utc + delay.to_i.minutes).iso8601
      else
        Jobs.enqueue(:discourse_activity_pub_deliver, args)
        @scheduled_at = Time.now.utc.iso8601
      end
    end

    def after_scheduled
      object.after_scheduled(scheduled_at) if object&.respond_to?(:after_scheduled)
    end

    def log_failure(message)
      return false unless SiteSetting.activity_pub_verbose_logging
      prefix = "#{actor.ap_id} failed to schedule #{object&.ap_id} for delivery"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{message}")
      false
    end
  end
end