# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubDeliver < ::Jobs::Base
    sidekiq_options queue: "low"

    MAX_RETRY_COUNT = 4
    RETRY_BACKOFF = 5

    def execute(args)
      @args = args
      return unless perform_request?
      perform_request
    end

    private

    def perform_request
      @performed = false
      retry_count = @args[:retry_count] || 0

      activity.address!(to_actor)

      # TODO (future): use request in a Request Pool
      request = DiscourseActivityPub::Request.new(
        actor_id: from_actor.id,
        uri: to_actor.inbox,
        body: activity.ap.json
      )

      # TODO (future): raise redirects from Request and resolve with FinalDestination
      if request&.post_json_ld
        @performed = true
      else
        retry_count += 1
        return if retry_count > MAX_RETRY_COUNT

        delay = RETRY_BACKOFF * (retry_count - 1)
        ::Jobs.enqueue_in(delay.minutes, :discourse_activity_pub_deliver, @args.merge(retry_count: retry_count))
      end
    ensure
      if @performed
        failure_tracker.track_success
        activity.after_deliver
      else
        failure_tracker.track_failure
      end
    end

    def perform_request?
      Site.activity_pub_enabled &&
        has_required_args? &&
        actors_ready? &&
        activity_ready? &&
        failure_tracker.domain_available?
    end

    def has_required_args?
      %i[activity_id from_actor_id to_actor_id].all? { |s| @args.key? s }
    end

    def failure_tracker
      @failure_tracker ||= DiscourseActivityPub::DeliveryFailureTracker.new(to_actor.inbox)
    end

    def activity
      @activity ||= DiscourseActivityPubActivity.find_by(id: @args[:activity_id])
    end

    def from_actor
      @from_actor ||= DiscourseActivityPubActor.find_by(id: @args[:from_actor_id])
    end

    def to_actor
      @to_actor ||= DiscourseActivityPubActor.find_by(id: @args[:to_actor_id])
    end

    def actors_ready?
      from_actor&.ready? && to_actor&.ready?
    end

    def activity_ready?
      activity&.ready?
    end
  end
end