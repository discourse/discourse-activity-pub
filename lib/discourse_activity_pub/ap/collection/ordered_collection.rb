# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection
      class OrderedCollection < Collection
        def type
          "OrderedCollection"
        end

        def ordered_items
          items.sort_by { |item| item.stored.created_at }.reverse
        end
      end
    end
  end
end