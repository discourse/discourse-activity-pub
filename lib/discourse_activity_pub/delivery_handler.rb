# frozen_string_literal: true
module DiscourseActivityPub
  class DeliveryHandler
    attr_reader :actor,
                :object,
                :recipient_ids,
                :scheduled_at

    def initialize(actor, object, recipient_ids)
      @actor = actor
      @object = object
      @recipient_ids = recipient_ids
    end

    def perform(delay: 0)
      return false unless can_deliver?
      schedule_deliveries(delay)
      after_scheduled
      object
    end

    def self.perform(actor: nil, object: nil, recipient_ids: nil, delay: 0)
      new(actor, object, recipient_ids).perform(delay: delay)
    end

    protected

    def can_deliver?
      return log_failure("delivery actor not ready") unless actor&.ready?
      return log_failure("object not ready") unless object&.ready?
      return log_failure("no recipients") unless recipients.any?
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
              address_to: actors.map(&:ap_id)
            }
            opts[:delay] = delay unless delay.nil?
            schedule_delivery(**opts)
          else
            # Recipient Actor does not have a shared inbox.
            actors.each do |actor|
              opts = {
                send_to: actor.inbox,
                address_to: [actor.ap_id],
              }
              opts[:delay] = delay unless delay.nil?
              schedule_delivery(**opts)
            end
          end
        end
    end

    def schedule_delivery(send_to: nil, address_to: [], delay: nil)
      return unless send_to && address_to.present?

      args = {
        object_id: object.id,
        object_type: object.class.name,
        from_actor_id: actor.id,
        send_to: send_to,
        address_to: address_to
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