# frozen_string_literal: true

module DiscourseActivityPub
  class Nodeinfo
    CONTENT_TYPE = "application/jrd+json"
    SUPPORTED_VERSION = "2.1"

    attr_reader :version

    def initialize(version)
      @version = version
    end

    def ready?
      version == SUPPORTED_VERSION
    end

    def self.index
      {
        links: [
          {
            rel: "http://nodeinfo.diaspora.software/ns/schema/#{SUPPORTED_VERSION}",
            href: "#{Discourse.base_url_no_prefix}/nodeinfo/#{SUPPORTED_VERSION}"
          }
        ]
      }.as_json
    end
  end
end
