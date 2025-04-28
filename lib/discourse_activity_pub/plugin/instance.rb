module DiscourseActivityPub
  module Plugin
    module Instance
      def activity_pub_on(activity, action, priority = 0, &block)
        DiscourseActivityPub::AP::Activity.add_handler(activity, action, priority) do |activity, opts = {}|
          block.call(activity, opts)
        end
      end
    end
  end
end