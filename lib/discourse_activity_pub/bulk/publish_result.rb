module DiscourseActivityPub
  module Bulk
    class PublishResult
      attr_accessor :collections,
                    :actors,
                    :objects,
                    :activities,
                    :announcements,
                    :finished

      def initialize
        @collections = []
        @actors = []
        @objects = []
        @activities = []
        @announcements = []
        @finished = false
      end

      def ap_ids
        [
          collections.map {|x| x["ap_id"] },
          actors.map {|x| x["ap_id"] },
          objects.map {|x| x["ap_id"] },
          activities.map {|x| x["ap_id"] },
          announcements.map {|x| x["ap_id"] },
        ].reduce([], :concat).compact
      end
    end
  end
end