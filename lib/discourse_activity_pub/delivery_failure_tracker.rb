# frozen_string_literal: true

# Based on mastodon/mastodon/app/lib/delivery_failure_tracker.rb

module DiscourseActivityPub
  class DeliveryFailureTracker
    FAILURE_DAYS_THRESHOLD = 7

    attr_reader :domain

    def initialize(uri)
      @domain = DiscourseActivityPub::URI.domain_from_uri(uri)
    end

    def track_failure
      add_to_failures
      set_domain_actors_as_unavailable if reached_failure_threshold?
    end

    def track_success
      clear_failures
      set_domain_actors_as_available
    end

    def domain_available?
      DiscourseActivityPubActor.where(domain: domain, available: true).exists?
    end

    def days
      Discourse.redis.scard(exhausted_deliveries_key) || 0
    end

    private

    def set_domain_actors_as_available
      DiscourseActivityPubActor.where(domain: domain).update_all(available: true)
    end

    def set_domain_actors_as_unavailable
      DiscourseActivityPubActor.where(domain: domain).update_all(available: false)
    end

    def clear_failures
      Discourse.redis.del(exhausted_deliveries_key)
    end

    def add_to_failures
      Discourse.redis.sadd(exhausted_deliveries_key, [today])
    end

    def exhausted_deliveries_key
      "discourse_activity_pub_exhausted_deliveries:#{domain}"
    end

    def today
      Time.now.utc.strftime('%Y%m%d')
    end

    def reached_failure_threshold?
      days >= FAILURE_DAYS_THRESHOLD
    end
  end
end