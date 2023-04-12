# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Collection < Object

      SUPPORTED_FOR = %w(outbox followers)

      attr_accessor :collection_for

      def initialize(stored: nil, collection_for: nil)
        raise ArgumentError.new("Unsupported collection_for") if collection_for && SUPPORTED_FOR.exclude?(collection_for)

        @stored = stored
        @collection_for = collection_for
      end

      def id
        collection_for ? stored.send(collection_for) : json_ld_id(type, SecureRandom.hex(16))
      end

      def type
        "Collection"
      end

      def items
        @items ||= collection_for ? self.send("#{collection_for}_items") : []
      end

      def outbox_items
        stored&.activities.map { |activity| activity.ap }
      end

      def followers_items
        stored&.followers.map { |follower| follower.ap }
      end

      def total_items
        items.size
      end
    end
  end
end