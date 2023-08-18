# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Like < Activity
        def type
          'Like'
        end
      end
    end
  end
end