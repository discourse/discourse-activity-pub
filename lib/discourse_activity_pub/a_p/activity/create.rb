# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Create < Compose
        def type
          "Create"
        end
      end
    end
  end
end
