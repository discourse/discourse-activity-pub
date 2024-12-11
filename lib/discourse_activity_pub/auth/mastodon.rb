# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    class Mastodon < Auth
      REDIRECT_PATH = "ap/auth/redirect/mastodon"
      AUTHORIZE_PATH = "oauth/authorize"
      APP_PATH = "api/v1/apps"
      APP_CHECK_PATH = "api/v1/apps/verify_credentials"
      TOKEN_PATH = "oauth/token"
      ACCOUNT_PATH = "api/v1/accounts/verify_credentials"
      SCOPES = "read"

      def name
        "mastodon"
      end

      def check_client
        request(
          APP_CHECK_PATH,
          verb: :get,
          headers: {
            "Authorization" => "Bearer #{client.credentials["access_token"]}",
          },
        )
      end

      def register_client
        client_response =
          request(
            APP_PATH,
            body: {
              client_name: DiscourseActivityPub.host,
              redirect_uris: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
              scopes: SCOPES,
              website: DiscourseActivityPub.base_url,
            },
          )
        return nil unless client_response
        credentials = client_response.slice(:client_id, :client_secret)

        token_response =
          request(
            TOKEN_PATH,
            body: {
              grant_type: "client_credentials",
              client_id: credentials[:client_id],
              client_secret: credentials[:client_secret],
              scope: SCOPES,
            },
          )
        return nil unless token_response
        credentials[:access_token] = token_response[:access_token]

        credentials
      end

      def get_authorize_url
        return nil unless client

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
        return nil unless client

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
