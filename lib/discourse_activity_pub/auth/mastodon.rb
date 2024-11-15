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

      def name
        "mastodon"
      end

      def register_client
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
        return nil unless response
        response.slice(:client_id, :client_secret)
      end

      def get_authorize_url
        uri = DiscourseActivityPub::URI.parse("https://#{domain}/#{AUTHORIZE_PATH}")
        uri.query =
          ::URI.encode_www_form(
            client_id: client.credentials["client_id"],
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

        response =
          request(
            TOKEN_PATH,
            body: {
              grant_type: "authorization_code",
              code: code,
              client_id: client.credentials["client_id"],
              client_secret: client.credentials["client_secret"],
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

      def get_account(token)
        request(ACCOUNT_PATH, verb: :get, headers: { "Authorization" => "Bearer #{token}" })
      end
    end
  end
end
