# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection < Object

      SUPPORTED_FOR = %w(inbox outbox)

      attr_accessor :collection_for

      def initialize(stored: nil, collection_for: nil)
        raise ArgumentError.new("Unsupported collection_for") unless SUPPORTED_FOR.include?(collection_for)

        @stored = stored
        @collection_for = collection_for
      end

      def id
        stored.send(collection_for)
      end

      def type
        "Collection"
      end

      def items
        @items ||= stored&.activities.map do |activity|
          "DiscourseActivityPub::AP::Activity::#{activity.ap_type}".classify.constantize.new(stored: activity)
        end
      end

      def total_items
        items.size
      end
    end
  end
end