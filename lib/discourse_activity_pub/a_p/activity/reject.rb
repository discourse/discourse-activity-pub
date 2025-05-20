# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Reject < Response
        def type
          "Reject"
        end
      end
    end
  end
end
