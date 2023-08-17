# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Application < Actor
        def type
          'Application'
        end

        def can_belong_to
          %i(remote)
        end

        def can_perform_activity
          {}
        end
      end
    end
  end
end