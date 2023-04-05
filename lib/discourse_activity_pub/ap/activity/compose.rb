# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Compose < Activity
        def types
          [Create.type, Delete.type, Update.type]
        end
      end
    end
  end
end