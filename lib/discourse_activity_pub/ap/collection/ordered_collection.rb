# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection
      class OrderedCollection < Collection
        def type
          "OrderedCollection"
        end

        def ordered_items
          @ordered_items ||= collection_for ? self.send("#{collection_for}_ordered_items") : []
        end

        def outbox_ordered_items
          items.sort_by { |item| item.start_time }.reverse
        end

        def followers_ordered_items
          stored&.follow_followers
            .sort_by { |follower| follower.created_at }
            .reverse
            .map { |follower| follower.follower.ap }
        end
      end
    end
  end
end