# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection < Object
      DEFAULT_PROCESSABLE_ITEMS_MAX = 2000

      attr_accessor :items_to_process

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

      def first
        json["first"] if json
      end

      def last
        json["last"] if json
      end

      def process
        resolve_items_to_process
        return unless items_to_process.present?

        success = []
        failure = []

        items_to_process.each do |item|
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

      def ordered_collection?
        type == AP::Collection::OrderedCollection.type
      end

      def resolve_items_to_process
        @items_to_process = ordered_collection? ? json["orderedItems"] : json["items"]
        return unless first && items_to_process.count <= processable_items_max
        @reached_max_items = false
        paginate(first)
      end

      protected

      def paginate(page_uri)
        page = AP::Object.resolve(page_uri)
        return unless page
        page_items = ordered_collection? ? page.ordered_items : page.items
        page_items.each do |item|
          if items_to_process.count < processable_items_max
            items_to_process << item
          else
            @reached_max_items = true
            break
          end
        end
        paginate(page.next) if page.next && !@reached_max_items
      end

      def processable_items_max
        (ENV["ACTIVITY_PUB_COLLECTION_PROCESSABLE_ITEMS_MAX"] || DEFAULT_PROCESSABLE_ITEMS_MAX).to_i
      end
    end
  end
end
