# frozen_string_literal: true

module Jobs
  module DiscourseActivityPub
    class TrackDelivery < ::Jobs::Base
      sidekiq_options queue: "low"

      def execute(args)
        tracker = ::DiscourseActivityPub::DeliveryFailureTracker.new(args[:send_to])
        if args[:delivered]
          tracker.track_success
        else
          tracker.track_failure
        end
      end
    end
  end
end
