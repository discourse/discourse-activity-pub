# frozen_string_literal: true
module DiscourseActivityPub
  class Webfinger
    class Handle
      SEPARATOR = "@"
      PREFIX = "@"

      attr_reader :raw_handle, :raw_username, :raw_domain

      def initialize(handle: nil, username: nil, domain: nil)
        if handle
          @raw_handle = handle
          @raw_username, _, @raw_domain = handle.rpartition(SEPARATOR)
        else
          @raw_username = username
          @raw_domain = domain
        end
      end

      def valid?
        username.present? && domain.present?
      end

      def username
        @username ||= raw_username.delete_prefix(PREFIX)
      end

      def domain
        @domain ||= DiscourseActivityPub::URI.domain_from_uri(raw_domain)
      end

      def to_s
        return nil unless valid?
        "#{username}#{SEPARATOR}#{domain}"
      end
    end
  end
end
