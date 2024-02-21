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
          %i[topic remote]
        end

        def process_items
          @process_items ||=
            begin
              return json["orderedItems"] if json["orderedItems"]

              if json["first"].present?
                page_href = json["first"].is_a?(String) ? json["first"] : json.dig("first", "href")
                page = request_object(page_href)
                page["orderedItems"]
              end
            end
        end
      end
    end
  end
end
