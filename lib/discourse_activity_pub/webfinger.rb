# frozen_string_literal: true

module DiscourseActivityPub
  class Webfinger
    CONTENT_TYPE = "application/jrd+json"
    ACCOUNT_SCHEME = "acct"
    SUPPORTED_SCHEMES = [ACCOUNT_SCHEME]
    PATH = ".well-known/webfinger"

    attr_reader :scheme

    def initialize(scheme)
      @scheme = scheme
    end

    def find(raw_handle)
      find_actor(raw_handle) if scheme === ACCOUNT_SCHEME
    end

    def find_actor(raw_handle)
      DiscourseActivityPubActor.find_by_handle(raw_handle, local: true, types: [permitted_types])
    end

    def permitted_types
      types = [DiscourseActivityPub::AP::Actor::Group.type]
      if DiscourseActivityPub.publishing_enabled
        types << DiscourseActivityPub::AP::Actor::Person.type
      end
      types
    end

    def self.resolve_handle(raw_handle)
      handle = Handle.new(handle: raw_handle)
      return nil if !handle.valid? || DiscourseActivityPub::URI.local?(handle.domain)

      query = "resource=#{ACCOUNT_SCHEME}:#{handle.to_s}"
      webfinger_uri = DiscourseActivityPub::URI.parse("https://#{handle.domain}/#{PATH}?#{query}")
      return nil unless webfinger_uri

      request = DiscourseActivityPub::Request.new(uri: webfinger_uri)
      request.expects = DiscourseActivityPub::Request::SUCCESS_CODES

      response = request.perform(:get)
      return nil unless response

      JsonLd.parse_json_ld(response.body)
    end

    def self.resolve_id_by_handle(raw_handle)
      account = resolve_handle(raw_handle)
      return nil unless account && account["links"].present?

      link = account["links"].find { |l| l["rel"] == "self" }
      return nil unless link && link["href"].present?

      link["href"]
    end

    def self.activity_link(href)
      { rel: "self", type: JsonLd::ACTIVITY_CONTENT_TYPE, href: href }
    end
  end
end
