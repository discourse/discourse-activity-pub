# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection < Object

      SUPPORTED_FOR = %w(inbox outbox)

      attr_accessor :model,
                    :collection_for

      def initialize(model: nil, collection_for: nil)
        raise ArgumentError.new("Unsupported collection_for") unless SUPPORTED_FOR.include?(collection_for)

        @collection_for = collection_for
        @model = model
      end

      def id
        @model.activity_pub_actor.send(collection_for)
      end

      def type
        "Collection"
      end

      def items
        @items ||= model.activity_pub_activities.map do |activity|
          "DiscourseActivityPub::AP::Activity::#{activity.ap_type}".classify.constantize.new(activity: activity)
        end
      end

      def total_items
        items.size
      end
    end
  end
end