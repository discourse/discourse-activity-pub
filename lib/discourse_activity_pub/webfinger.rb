# frozen_string_literal: true

module DiscourseActivityPub
  class Webfinger
    CONTENT_TYPE = "application/jrd+json"
    ACCOUNT_SCHEME = "acct"
    SUPPORTED_SCHEMES = [ACCOUNT_SCHEME]

    attr_reader :scheme

    def initialize(scheme)
      @scheme = scheme
    end

    def find(uri)
      find_actor(uri) if scheme === ACCOUNT_SCHEME
    end

    def find_actor(uri)
      DiscourseActivityPubActor.find_by_handle(uri, local: true)
    end

    def self.activity_link(href)
      { rel: 'self', type: JsonLd::ACTIVITY_CONTENT_TYPE, href: href }
    end
  end
end