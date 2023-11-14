module DiscourseActivityPub
    class Webfinger
        class Handle
            SEPERATOR = "@"
            PREFIX = "@"

            attr_reader :raw_handle,
                        :raw_username,
                        :raw_domain

            def initialize(raw_handle)
                @raw_handle = raw_handle
                @raw_username, _, @raw_domain = raw_handle.rpartition(SEPERATOR)
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
                "#{username}#{SEPERATOR}#{domain}"
            end
        end
    end
end