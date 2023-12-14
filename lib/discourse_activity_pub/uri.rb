# frozen_string_literal: true
module DiscourseActivityPub
  class URI
    SUPPORTED_SCHEMES = %w(http https)

    def self.parse(uri)
      uri = "http://#{uri}" if Addressable::URI.parse(uri).scheme.nil?
      Addressable::URI.parse(uri)
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def self.valid_url?(uri)
      parsed = Addressable::URI.parse(uri)
      SUPPORTED_SCHEMES.include?(parsed.scheme)
    rescue Addressable::URI::InvalidURIError
      false
    end

    def self.domain_from_uri(uri)
      uri && parse(uri)&.host
    rescue Addressable::URI::InvalidURIError
      nil
    end

    def self.matching_hosts?(uri1, uri2)
      domain_from_uri(uri1) == domain_from_uri(uri2)
    end

    def self.local?(uri)
      uri = parse(uri)
      return false unless uri

      if Rails.application.config.hosts.present?
        Rails.application.config.hosts.any? do |allowed_host|
          regex = Regexp.new(allowed_host.to_s)
          uri.host =~ regex
        end
      else
        uri.host === DiscourseActivityPub.host
      end
    rescue Addressable::URI::InvalidURIError
      false
    end
  end
end