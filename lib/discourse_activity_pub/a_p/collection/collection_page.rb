# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection
      class CollectionPage < Collection
        def type
          "CollectionPage"
        end

        def part_of
          json["partOf"] if json
        end

        def next
          json["next"] if json
        end

        def prev
          json["prev"] if json
        end

        def items
          json["items"] if json
        end

        def can_belong_to
          %i[remote]
        end
      end
    end
  end
end
