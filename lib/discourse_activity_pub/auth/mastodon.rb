# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class Mastodon < Authorization
      REDIRECT_PATH = "ap/auth/redirect/mastodon"
      APP_PATH = "api/v1/apps"
      TOKEN_PATH = "oauth/token"
      ACCOUNT_PATH = "api/v1/accounts/verify_credentials"
      SCOPES = "read:accounts"

      def platform_store_key
        "oauth"
      end

      def verify
        if create_app
          true
        else
          add_error(I18n.t("discourse_activity_pub.auth.error.failed_to_create_app"))
          false
        end
      end

      def create_app
        app = get_app
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

      def get_authorize_url
        app = get_app
        return unless app

        uri = DiscourseActivityPub::URI.parse("https://#{domain}/auth/authorize")
        return unless uri

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

      def get_token(params)
        code = params[:code]
        return unless code

        app = get_app
        return unless app

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
        return unless response

        response.dig(:access_token)
      end

      def get_actor_id(access_token)
        account = get_account(access_token)
        account_to_actor_id(account) if account
      end

      def get_account(access_token)
        request(ACCOUNT_PATH, verb: :get, headers: { "Authorization" => "Bearer #{access_token}" })
      end

      protected

      def account_to_actor_id(account)
        "https://#{domain}/users/#{account["username"]}"
      end
    end
  end
end
