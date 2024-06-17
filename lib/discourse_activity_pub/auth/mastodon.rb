# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    class Mastodon < Auth
      REDIRECT_PATH = "ap/auth/redirect/mastodon"
      AUTHORIZE_PATH = "oauth/authorize"
      APP_PATH = "api/v1/apps"
      TOKEN_PATH = "oauth/token"
      ACCOUNT_PATH = "api/v1/accounts/verify_credentials"
      SCOPES = "read:accounts"

      def verify
        auth_error("failed_to_create_app") unless create_app
      end

      def get_authorize_url
        return auth_error("failed_to_find_app") unless app

        uri = DiscourseActivityPub::URI.parse("https://#{domain}/#{AUTHORIZE_PATH}")
        uri.query =
          ::URI.encode_www_form(
            client_id: app.client_id,
            response_type: "code",
            redirect_uri: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
            scope: SCOPES,
            force_login: true,
          )
        uri.to_s
      end

      def get_token(params = {})
        code = params[:code]

        return auth_error("invalid_redirect_params") unless code
        return auth_error("failed_to_find_app") unless app

        response =
          request(
            TOKEN_PATH,
            body: {
              grant_type: "authorization_code",
              code: code,
              client_id: app.client_id,
              client_secret: app.client_secret,
              redirect_uri: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
              scope: SCOPES,
            },
          )
        return auth_error("failed_to_get_token") unless response

        response.dig(:access_token)
      end

      def get_actor_ap_id(token)
        account = get_account(token)
        return auth_error("failed_to_get_actor") unless account
        "https://#{domain}/users/#{account["username"]}"
      end

      def create_app
        return app if app

        response =
          request(
            APP_PATH,
            body: {
              client_name: DiscourseActivityPub.host,
              redirect_uris: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
              scopes: SCOPES,
              website: DiscourseActivityPub.base_url,
            },
          )
        return unless response

        save_app(response.slice(:client_id, :client_secret))
        get_app
      end

      def save_app(data)
        PluginStore.set(plugin_store_name, domain, data)
      end

      def get_app
        data = PluginStore.get(plugin_store_name, domain)
        data ? App.new(domain, data) : nil
      end

      def plugin_store_name
        "#{DiscourseActivityPub::PLUGIN_NAME}-oauth-app"
      end

      def get_account(token)
        request(ACCOUNT_PATH, verb: :get, headers: { "Authorization" => "Bearer #{token}" })
      end

      def self.get_app(domain)
        new(domain: domain).get_app
      end

      def self.save_app(domain, data)
        new(domain: domain).save_app(data)
      end

      def self.create_app(domain)
        new(domain: domain).create_app
      end

      def self.plugin_store_name
        new.plugin_store_name
      end

      protected

      def app
        @app ||= get_app
      end
    end
  end
end
