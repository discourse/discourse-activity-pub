# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Person < Actor
        def type
          'Person'
        end

        def can_belong_to
          %i(remote)
        end

        def can_perform_activity
          {
            follow: [:group],
            undo: [:follow]
          }
        end
      end
    end
  end
end