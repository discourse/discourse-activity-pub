# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Update < Compose
        def type
          'Update'
        end
      end
    end
  end
end