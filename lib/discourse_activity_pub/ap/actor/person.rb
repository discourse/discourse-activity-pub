# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Person < Actor
        def type
          "Person"
        end

        def can_belong_to
          %i[remote user]
        end

        def can_perform_activity
          {
            accept: [:follow],
            reject: [:follow],
            follow: [:group],
            undo: %i[follow like],
            create: %i[note article],
            update: %i[note article],
            delete: %i[note article],
            like: %i[note article],
            announce: %i[note article],
          }
        end
      end
    end
  end
end
