# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Compose < Activity
        def types
          [Create.type, Delete.type, Update.type]
        end

        def validate_activity
          unless activity_host_matches_object_host?
            raise DiscourseActivityPub::AP::Handlers::Warning
          end
          super
        end
      end
    end
  end
end
