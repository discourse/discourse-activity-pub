# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Accept < Response
        def type
          "Accept"
        end
      end
    end
  end
end
