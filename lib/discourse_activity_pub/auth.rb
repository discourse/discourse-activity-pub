# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    include JsonLd
    include HasErrors

    attr_reader :domain
    attr_accessor :auth_id

    def initialize(domain: nil, auth_id: nil)
      @domain = domain
      @auth_id = auth_id
    end

    def authorization
      @authorization ||= DiscourseActivityPubAuthorization.find_by(id: auth_id)
    end

    def success?
      errors.blank?
    end

    def verify
      raise NotImplementedError
    end

    def get_authorize_url
      raise NotImplementedError
    end

    def get_token(params)
      raise NotImplementedError
    end

    def get_actor_ap_id(token)
      raise NotImplementedError
    end

    def self.verify(domain)
      new(domain: domain).verify
    end

    def self.get_authorize_url(domain: nil, auth_id: nil)
      new(domain: domain, auth_id: auth_id).get_authorize_url
    end

    def self.get_token(domain: nil, auth_id: nil, params: {})
      new(domain: domain, auth_id: auth_id).get_token(params)
    end

    def self.get_actor_ap_id(domain: nil, auth_id: nil, token: nil)
      new(domain: domain, auth_id: auth_id).get_actor_ap_id(token)
    end

    protected

    def auth_error(key)
      add_error(I18n.t("discourse_activity_pub.auth.error.#{key}"))
      return nil
    end

    def request(path, verb: :post, body: nil, headers: nil, params: nil)
      uri = DiscourseActivityPub::URI.parse("https://#{domain}/#{path}")
      uri.query = ::URI.encode_www_form(params) if params

      opts = {}
      opts[:body] = body.to_json if body
      opts[:headers] = {}
      opts[:headers]["Content-Type"] = "application/json" if body
      headers.each { |k, v| opts[:headers][k] = v } if headers

      begin
        response = Excon.send(verb, uri.to_s, opts)
      rescue Excon::Error => e
        add_error(e.message)
      end

      if response&.body && raw = parse_json_ld(response.body)
        body_hash = raw.with_indifferent_access if raw.is_a?(Hash)
      end

      if ![200, 201, 202].include?(response&.status)
        if body_hash
          errors = [
            body_hash[:error],
            body_hash[:error_description],
            body_hash[:errors],
          ].flatten.compact
          errors.each { |error| add_error(error) }
        end
        return false
      end

      body_hash || true
    end
  end
end
