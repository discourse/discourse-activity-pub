# frozen_string_literal: true
module DiscourseActivityPub
  module DomainVerification
    def ensure_domain_allowed
      render_activity_pub_error("forbidden", 403) unless domain_allowed?(request_domain)
    end

    def domain_allowed?(domain)
      return allowed_domains.include?(domain) if allowed_domains.any?
      return blocked_domains.exclude?(domain) if blocked_domains.any?
      true
    end

    def request_domain
      DiscourseActivityPub::URI.domain_from_uri(request.origin)
    end

    def allowed_domains
      @allowed_domains ||= SiteSetting.activity_pub_allowed_request_origins.split('|')
    end

    def blocked_domains
      @blocked_domains ||= SiteSetting.activity_pub_blocked_request_origins.split('|')
    end
  end
end