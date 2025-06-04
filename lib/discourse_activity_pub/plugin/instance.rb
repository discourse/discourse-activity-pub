# frozen_string_literal: true
module DiscourseActivityPub
  module Plugin
    module Instance
      def activity_pub_on(activity, action, priority = 0, &block)
        DiscourseActivityPub::AP::Activity.add_handler(
          activity,
          action,
          priority,
        ) { |_activity, opts = {}| block.call(_activity, opts) }
      end
    end
  end
end
