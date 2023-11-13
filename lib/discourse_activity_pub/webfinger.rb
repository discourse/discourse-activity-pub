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

    def find(uri)
      find_actor(uri) if scheme === ACCOUNT_SCHEME
    end

    def find_actor(uri)
      DiscourseActivityPubActor.find_by_handle(uri, local: true)
    end

    def self.find_by_handle(handle)
      username, domain = handle.split('@')
      return nil if DiscourseActivityPub::URI.local?(domain)

      query = "resource=#{ACCOUNT_SCHEME}:#{handle}"
      uri = DiscourseActivityPub::URI.parse("https://#{domain}/#{PATH}?#{query}")
      return nil unless uri

      request = DiscourseActivityPub::Request.new(uri: uri)
      request.expects = DiscourseActivityPub::Request::SUCCESS_CODES

      response = request.perform(:get)
      return nil unless response

      JsonLd.parse_json_ld(response.body)
    end

    def self.find_id_by_handle(handle)
      account = find_by_handle(handle)
      return nil unless account && account['links'].present?

      link = account['links'].find { |l| l['rel'] == 'self' }
      return nil unless link && link['href'].present?

      link['href']
    end

    def self.activity_link(href)
      { rel: 'self', type: JsonLd::ACTIVITY_CONTENT_TYPE, href: href }
    end
  end
end