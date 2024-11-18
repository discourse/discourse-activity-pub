# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    include JsonLd
    include HasErrors

    attr_reader :domain
    attr_accessor :auth_id

    def initialize(domain: nil)
      @domain = domain
    end

    def verify_client
      create_client if !client
      auth_error("failed_to_verify_client") unless client && check_client
    end

    def auth_type
      DiscourseActivityPubClient.auth_types[name.to_sym]
    end

    def client
      @client ||= DiscourseActivityPubClient.find_by(auth_type: auth_type, domain: domain)
    end

    def create_client
      credentials = register_client
      return nil unless credentials
      @client =
        DiscourseActivityPubClient.create!(
          auth_type: auth_type,
          domain: domain,
          credentials: credentials,
        )
    end

    def authorization
      @authorization ||= DiscourseActivityPubAuthorization.find_by(id: auth_id)
    end

    def success?
      errors.blank?
    end

    def check_client
      raise NotImplementedError
    end

    def register_client
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

    def self.get_authorize_url(domain: nil)
      new(domain: domain).get_authorize_url
    end

    def self.get_token(domain: nil, params: {})
      new(domain: domain).get_token(params)
    end

    def self.get_actor_ap_id(domain: nil, token: nil)
      new(domain: domain).get_actor_ap_id(token)
    end

    protected

    def auth_error(key, opts = {})
      add_error(I18n.t("discourse_activity_pub.auth.error.#{key}", opts))
      nil
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
