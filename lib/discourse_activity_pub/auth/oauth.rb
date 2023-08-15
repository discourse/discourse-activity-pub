# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class OAuth
      include ActiveModel::SerializerSupport
      include JsonLd
      include HasErrors

      REDIRECT_PATH = "ap/auth/oauth/redirect"
      APP_PATH = "api/v1/apps"
      TOKEN_PATH = "oauth/token"
      ACCOUNT_PATH = "api/v1/accounts/verify_credentials"
      SCOPES = "read:accounts"
      PLUGIN_STORE_KEY = "#{DiscourseActivityPub::PLUGIN_NAME}-oauth-app"

      attr_reader :domain

      def initialize(domain)
        @domain = domain
      end

      def create_app
        app = get_app
        return app if app

        response = request(APP_PATH, body: {
          client_name: DiscourseActivityPub.host,
          redirect_uris: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
          scopes: SCOPES,
          website: DiscourseActivityPub.base_url
        })
        return unless response

        save_app(response)
        get_app
      end

      def get_authorize_url
        app = get_app
        return unless app

        uri = DiscourseActivityPub::URI.parse(
          "https://#{domain}/oauth/authorize"
        )
        return unless uri

        uri.query = ::URI.encode_www_form(
          client_id: app.client_id,
          response_type: 'code',
          redirect_uri: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
          scope: SCOPES,
          force_login: true
        )
        uri.to_s
      end

      def get_token(code)
        app = get_app
        return unless app

        response = request(TOKEN_PATH, body: {
          grant_type: 'authorization_code',
          code: code,
          client_id: app.client_id,
          client_secret: app.client_secret,
          redirect_uri: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
          scope: SCOPES
        })
        return unless response

        response.dig(:access_token)
      end

      def get_actor_id(access_token)
        account = get_account(access_token)
        account_to_actor_id(account) if account
      end

      def get_account(access_token)
        request(
          ACCOUNT_PATH,
          verb: :get,
          headers: {
            'Authorization' => "Bearer #{access_token}"
          }
        )
      end

      def self.create_app(domain)
        new(domain).create_app
      end

      def self.get_authorize_url(domain)
        new(domain).get_authorize_url
      end

      def self.get_token(domain, code)
        new(domain).get_token(code)
      end

      def self.get_actor_id(domain, access_token)
        new(domain).get_actor_id(access_token)
      end

      protected

      def save_app(response)
        PluginStore.set(PLUGIN_STORE_KEY, domain, response)
      end

      def get_app
        data = PluginStore.get(PLUGIN_STORE_KEY, domain)
        data ? App.new(domain, data) : nil
      end

      def request(path, verb: :post, body: nil, headers: nil)
        url = "https://#{domain}/#{path}"

        opts = {}
        opts[:body] = body.to_json if body
        opts[:headers] = {}
        opts[:headers]['Content-Type'] = 'application/json' if body
        if headers
          headers.each do |k, v|
            opts[:headers][k] = v
          end
        end

        begin
          response = Excon.send(verb, url, opts)
        rescue Excon::Error => e
          add_error(e.message)
        end

        body_hash = if response&.body
                      raw = parse_json_ld(response.body)
                      raw&.with_indifferent_access
                    else
                      nil
                    end

        if ![200, 201, 202].include?(response&.status) && body_hash
          # The mastodon docs and code vary on use of "error", "errors" and "error_description".
          errors = [body_hash[:error], body_hash[:error_description], body_hash[:errors]].flatten.compact
          errors.each { |error| add_error(error) }
        end

        errors.blank? && body_hash
      end

      # May support other platforms other than standard Mastodon in the future
      def account_to_actor_id(account)
        # Standard Mastodon actor id.
        "https://#{domain}/users/#{account['username']}"
      end
    end
  end
end