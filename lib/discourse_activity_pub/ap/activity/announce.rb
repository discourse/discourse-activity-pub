# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Announce < Activity
        def type
          "Announce"
        end

        def process
          @actor = Actor.resolve_and_store(json[:actor])
          return process_failed("cant_create_actor") if actor.blank?

          @object = Object.resolve_and_store(json[:object], self)
          return process_failed("cant_find_object") if object.blank?

          if object.object?
            # If the Announce wraps an object we process the Announce.
            # See https://github.com/mastodon/mastodon/issues/16974
            return process_failed("object_not_ready") unless object.stored&.ready?(type)
            unless actor.stored.can_perform_activity?(type, object.type)
              return process_failed("activity_not_supported")
            end
            return false unless perform_validate_activity

            perform_transactions
            forward_activity
          else
            # If the Announce wraps an activity we process the Activity and discard the Announce.
            # See https://codeberg.org/fediverse/fep/src/branch/main/fep/1b12/fep-1b12.md#the-announce-activity
            return false unless perform_validate_activity
            object.parent = self
            object.delivered_to << delivered_to if delivered_to
            object.process
          end
        end
      end
    end
  end
end
