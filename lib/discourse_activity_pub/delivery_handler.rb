# frozen_string_literal: true
module DiscourseActivityPub
  class DeliveryHandler
    attr_reader :actor,
                :object,
                :recipients,
                :scheduled_at

    def initialize(actor, object, recipients)
      @actor = actor
      @object = object
      @recipients = recipients
    end

    def perform(delay: 0)
      return false unless can_deliver?
      schedule_deliveries(delay)
      after_scheduled
      object
    end

    def self.perform(actor: nil, object: nil, recipients: nil, delay: 0)
      new(actor, object, recipients).perform(delay: delay)
    end

    protected

    def can_deliver?
      return log_failure("delivery actor not ready") unless actor&.ready?
      return log_failure("object not ready") unless object&.ready?
      return log_failure("no recipients") unless recipients.present?
      true
    end

    def schedule_deliveries(delay = nil)
      recipients
        .uniq { |r| r.id }
        .group_by(&:shared_inbox)
        .each do |shared_inbox, recipient_actors|
          if shared_inbox
            opts = {
              send_to: shared_inbox,
              address_to: recipient_actors.map(&:ap_id)
            }
            opts[:delay] = delay unless delay.nil?
            schedule_delivery(**opts)
          else
            # Recipient Actor does not have a shared inbox.
            recipient_actors.each do |recipient_actor|
              opts = {
                send_to: recipient_actor.inbox,
                address_to: [recipient_actor.ap_id],
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