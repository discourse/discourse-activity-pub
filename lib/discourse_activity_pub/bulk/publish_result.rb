# frozen_string_literal: true
module DiscourseActivityPub
  module Bulk
    class PublishResult
      attr_accessor :collections, :actors, :objects, :activities, :announcements, :finished

      def initialize
        @collections = []
        @actors = []
        @objects = []
        @activities = []
        @announcements = []
        @finished = false
      end

      def ap_ids
        [collections, actors, objects, activities, announcements].reduce([], :concat).compact
      end
    end
  end
end
