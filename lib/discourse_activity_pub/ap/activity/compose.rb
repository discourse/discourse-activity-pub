# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Compose < Activity
        def types
          [Create.type, Delete.type, Update.type]
        end

        def deliver
          # TODO: perhaps add batching?
          stored.actor.followers.each do |follower|
            enqueue_delivery(follower.inbox)
          end
        end
      end
    end
  end
end