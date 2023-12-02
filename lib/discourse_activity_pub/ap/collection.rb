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

      def process_items
        json["items"]
      end

      def process
        process_items.each do |item|
          activity = DiscourseActivityPub::AP::Activity.factory(item)

          if activity&.respond_to?(:process)
            activity.delivered_to << delivered_to if delivered_to
            activity.process
          end
        end
      end

      def can_belong_to
        %i()
      end
    end
  end
end