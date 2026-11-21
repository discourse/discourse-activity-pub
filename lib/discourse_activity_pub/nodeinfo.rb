# frozen_string_literal: true

module DiscourseActivityPub
  class Nodeinfo
    include ActiveModel::Serialization

    VERSION = "2.1"
    SOFTWARE_NAME = "discourse"

    # See https://github.com/jhass/nodeinfo/blob/main/schemas/2.1/schema.json for supported enums.
    SUPPORTED_PROTOCOLS = %w[activitypub]
    SUPPORTED_INBOUND_SERVICES = %w[rss2.0 pop3]
    SUPPORTED_OUTBOUND_SERVICES = %w[rss2.0 smtp]

    attr_reader :version

    def initialize(version)
      @version = version.to_s
    end

    def supported_version?
      version == VERSION
    end

    def software
      { name: SOFTWARE_NAME, version: Discourse::VERSION::STRING }
    end

    def protocols
      SUPPORTED_PROTOCOLS
    end

    def services
      { inbound: SUPPORTED_INBOUND_SERVICES, outbound: SUPPORTED_OUTBOUND_SERVICES }
    end

    def usage
      {
        users: {
          total: ::Statistics.nodeinfo[:users_total],
          active_month: ::Statistics.nodeinfo[:users_seen_month],
          active_half_year: ::Statistics.nodeinfo[:users_seen_half_year],
        },
        local_posts: ::Statistics.nodeinfo[:posts_local],
        local_comments: ::Statistics.nodeinfo[:replies_local],
      }
    end

    def open_registrations
      !SiteSetting.login_required
    end

    # Compare https://mastodon.social/nodeinfo/2.0
    def metadata
      { node_name: SiteSetting.title, node_description: SiteSetting.site_description }
    end

    def self.index
      {
        links: [
          {
            rel: "http://nodeinfo.diaspora.software/ns/schema/#{VERSION}",
            href: "#{Discourse.base_url_no_prefix}/nodeinfo/#{VERSION}",
          },
        ],
      }.as_json
    end
  end
end
