# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Undo < Activity
        def type
          'Undo'
        end

        def validate_activity
          return true if actor.id === object.actor.id
          process_failed("invalid_undo")
        end

        def perform_activity
          case object.type
          when AP::Activity::Follow.type
            DiscourseActivityPubFollow.where(
              follower_id: actor.stored.id,
              followed_id: object.object.stored.id
            ).destroy_all
          else
            false
          end
        end
      end
    end
  end
end