# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection
      class OrderedCollection < Collection
        def type
          "OrderedCollection"
        end

        def ordered_items
          # TODO: order items by creation
          items
        end
      end
    end
  end
end