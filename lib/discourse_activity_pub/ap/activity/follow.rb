# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Follow < Activity
        def type
          'Follow'
        end
      end
    end
  end
end
