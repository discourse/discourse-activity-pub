# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Link
      attr_accessor :value

      def initialize(value = nil)
        @value = value
      end

      def type
        "Link"
      end

      def href
        return value if value.is_a?(String)
        value[:href] if value.is_a?(Hash)
      end

      def media_type
        value[:mediaType] if value.is_a?(Hash)
      end

      def name
        value[:name] if value.is_a?(Hash)
      end
    end
  end
end
