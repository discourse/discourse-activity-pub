# frozen_string_literal: true
module DiscourseActivityPub
  module Plugin
    module Instance
      def activity_pub_on(activity, action, priority = 0, &block)
        DiscourseActivityPub::AP::Activity.add_handler(
          activity,
          action,
          priority,
        ) { |activity, opts = {}| block.call(activity, opts) }
      end
    end
  end
end
