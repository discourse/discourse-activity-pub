# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection
      class OrderedCollectionPage < CollectionPage
        def type
          "OrderedCollectionPage"
        end

        def ordered_items
          json["orderedItems"] if json
        end

        def startIndex
          json["startIndex"]
        end
      end
    end
  end
end
