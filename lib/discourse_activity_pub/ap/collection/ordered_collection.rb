# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection
      class OrderedCollection < Collection
        def type
          "OrderedCollection"
        end

        def ordered_items
          @ordered_items ||= items.sort_by { |item| item.start_time }.reverse
        end

        def can_belong_to
          %i(topic)
        end

        def process_items
          json["orderedItems"]
        end
      end
    end
  end
end