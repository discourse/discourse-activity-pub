# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Undo < Activity
        def type
          'Undo'
        end

        def validate_activity
          if actor.id != object.actor.id
            process_failed("undo_actor_must_match_object_actor")
            return false
          end
          return false unless activity_host_matches_object_host?
          super
        end
      end
    end
  end
end