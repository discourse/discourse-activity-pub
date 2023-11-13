# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Actor
      class Service < Actor
        def type
          'Service'
        end

        def can_belong_to
          %i()
        end

        def can_perform_activity
          {}
        end
      end
    end
  end
end