# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Announce < Activity
        def type
          'Announce'
        end
      end
    end
  end
end