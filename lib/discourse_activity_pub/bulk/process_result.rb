# frozen_string_literal: true
module DiscourseActivityPub
  module Bulk
    class ProcessResult
      attr_accessor :activities_by_ap_id,
                    :actors_by_ap_id,
                    :objects_by_ap_id,
                    :collections_by_ap_id,
                    :users_by_actor_ap_id,
                    :posts_by_object_ap_id,
                    :topics_by_collection_ap_id,
                    :finished

      def initialize
        @finished = false
        @activities_by_ap_id = {}
        @actors_by_ap_id = {}
        @objects_by_ap_id = {}
        @collections_by_ap_id = {}
        @users_by_actor_ap_id = {}
        @posts_by_object_ap_id = {}
        @topics_by_collection_ap_id = {}
      end

      def activities
        activities_by_ap_id.values
      end

      def actors
        actors_by_ap_id.values
      end

      def objects
        objects_by_ap_id.values
      end

      def collections
        collections_by_ap_id.values
      end

      def users
        users_by_actor_ap_id.values
      end

      def posts
        posts_by_object_ap_id.values
      end

      def topics
        topics_by_collection_ap_id.values
      end
    end
  end
end
