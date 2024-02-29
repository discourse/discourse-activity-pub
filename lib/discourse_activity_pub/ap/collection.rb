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
        return items.size if stored
        json["totalItems"] if json
      end

      def process_items
        json["items"]
      end

      def process
        return if !process_items

        success = []
        failure = []

        process_items.reverse.each do |item|
          activity = DiscourseActivityPub::AP::Activity.factory(item)

          if activity.respond_to?(:process)
            activity.delivered_to << delivered_to if delivered_to

            result = activity.process
            if result
              success << result.stored.ap_id
            else
              failure << activity.json[:id]
            end
          else
            failure << I18n.t("discourse_activity_pub.process.warning.invalid_collection_item")
          end
        end

        { success: success, failure: failure }
      end

      def can_belong_to
        %i[]
      end
    end
  end
end
