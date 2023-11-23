# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Announce < Activity
        def type
          'Announce'
        end

        # See further https://codeberg.org/fediverse/fep/src/branch/main/fep/1b12/fep-1b12.md#the-announce-activity
        def process
          @actor = Actor.resolve_and_store(json[:actor])
          return process_failed("cant_create_actor") unless actor.present?

          @object = Object.resolve_and_store(json[:object], self)
          return process_failed("cant_find_object") unless object.present?
          return false unless process_activity_targets
          return false unless perform_validate_activity

          object.parent_actor = @actor
          object.process
        end
      end
    end
  end
end