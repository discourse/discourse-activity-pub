# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubDeliver < ::Jobs::Base
    sidekiq_options queue: "low"

    MAX_RETRY_COUNT = 4
    RETRY_BACKOFF = 5
    DELIVERABLE_OBJECTS = %w(DiscourseActivityPubActivity DiscourseActivityPubCollection)

    def execute(args)
      @args = args
      return unless perform_request?
      before_perform_request
      perform_request
      after_perform_request
    end

    private

    def perform_request
      @delivered = false
      retry_count = @args[:retry_count] || 0

      # TODO (future): use request in a Request Pool
      request = DiscourseActivityPub::Request.new(
        actor_id: from_actor.id,
        uri: @args[:send_to],
        body: delivery_json
      )

      # TODO (future): raise redirects from Request and resolve with FinalDestination
      if request&.post_json_ld
        @delivered = true
      else
        retry_count += 1
        return if retry_count > MAX_RETRY_COUNT

        delay = RETRY_BACKOFF * (retry_count - 1)
        ::Jobs.enqueue_in(delay.minutes, :discourse_activity_pub_deliver, @args.merge(retry_count: retry_count))
      end
    ensure
      if @delivered
        log_success
        failure_tracker.track_success
      else
        log_failure
        failure_tracker.track_failure
      end
    end

    def perform_request?
      DiscourseActivityPub.enabled &&
        has_required_args? &&
        actors_ready? &&
        object_ready? &&
        failure_tracker.domain_available?
    end

    def has_required_args?
      %i[from_actor_id send_to].all? { |key| @args[key].present? }
    end

    def failure_tracker
      @failure_tracker ||= DiscourseActivityPub::DeliveryFailureTracker.new(@args[:send_to])
    end

    def object
      @object ||= begin
        return nil unless @args[:object_type] && @args[:object_id]
        @args[:object_type].constantize.find_by(id: @args[:object_id])
      end
    end

    def from_actor
      @from_actor ||= DiscourseActivityPubActor.find_by(id: @args[:from_actor_id])
    end

    def actors_ready?
      from_actor&.ready?
    end

    def object_ready?
      DELIVERABLE_OBJECTS.include?(@args[:object_type]) && object&.ready? && delivery_object.present?
    end

    def announcing?
      # If an actor is delivering a collection of activities, or delivering a create activity they didn't perform they announce (share) them.
      # See further https://codeberg.org/fediverse/fep/src/branch/main/fep/1b12/fep-1b12.md#the-announce-activity
      @announcing ||= object.ap.collection? || from_actor.id != object.actor.id
    end

    def delivery_object
      @delivery_object ||= begin
        if announcing?
          begin
            object.announce!(from_actor.id)
            object
          rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
            log_failure(e.message)
          end
        else
          object
        end
      end
    end

    def delivery_json
      @delivery_json ||= begin
        final_object = announcing? ? delivery_object.announcement : delivery_object
        final_object.ap.json
      end
    end

    def log_failure(message = "Failed to POST")
      return false unless SiteSetting.activity_pub_verbose_logging
      prefix = "#{from_actor.ap_id} failed to deliver #{JSON.generate(delivery_json)}"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{message}")
    end
  
    def log_success
      return false unless SiteSetting.activity_pub_verbose_logging
      prefix = "JSON delivered to #{@args[:send_to]}"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{JSON.generate(delivery_json)}")
    end

    def before_perform_request
      object.before_deliver if object.present?
    end

    def after_perform_request
      object.after_deliver(@delivered) if object.present?
    end
  end
end