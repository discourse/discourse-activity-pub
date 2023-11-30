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
        "Collection"
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
    end
  end
end
