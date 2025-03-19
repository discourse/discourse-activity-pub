# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Service < Actor
        def type
          "Service"
        end

        def can_belong_to
          %i[remote]
        end

        def can_perform_activity
          {
            accept: [:follow],
            reject: [:follow],
            follow: [:group],
            undo: %i[follow],
            create: %i[note article],
            update: %i[note article],
            delete: %i[note article],
            announce: %i[note article],
          }
        end
      end
    end
  end
end
