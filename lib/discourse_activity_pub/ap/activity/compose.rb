# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Compose < Activity
        def types
          [Create.type, Delete.type, Update.type]
        end

        def validate_activity
          return false unless activity_host_matches_object_host?
          super
        end
      end
    end
  end
end
