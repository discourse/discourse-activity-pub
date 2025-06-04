# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Delete < Compose
        def type
          "Delete"
        end
      end
    end
  end
end
