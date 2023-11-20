# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection < Object

      def id
        stored.ap_id
      end

      def type
        "Collection"
      end

      def base_type
        'Collection'
      end

      def items
        @items ||= (stored&.items || []).map { |item| item.ap }
      end

      def total_items
        items.size
      end

      def summary
        stored&.summary
      end

      def process_items
        json["items"]
      end

      def process
        process_items.each do |item|
          activity = DiscourseActivityPub::AP::Activity.factory(item)
          activity.process if activity&.respond_to?(:process)
        end
      end
    end
  end
end