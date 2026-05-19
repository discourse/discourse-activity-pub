# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    class Gotosocial < Auth
      REDIRECT_PATH = "ap/auth/redirect/gotosocial"
      AUTHORIZE_PATH = "oauth/authorize"
      APP_PATH = "api/v1/apps"
      APP_CHECK_PATH = "api/v1/apps/verify_credentials"
      TOKEN_PATH = "oauth/token"
      ACCOUNT_PATH = "api/v1/accounts/verify_credentials"
      SCOPES = "profile"
      NODEINFO_PATH = ".well-known/nodeinfo"

      def name
        "gotosocial"
      end

      def verify_client
        # Check nodeinfo first. If it fails, don't even try to register or check client.
        return auth_error("failed_to_verify_client") unless check_client
        super
      end

      def check_client
        # First verify it's a valid ActivityPub instance via nodeinfo
        nodeinfo_response = request(NODEINFO_PATH, verb: :get)
        return false unless nodeinfo_response

        # Check if it's actually GoToSocial by examining nodeinfo
        return false unless is_gotosocial_instance?(nodeinfo_response)

        # For GoToSocial, we avoid OAuth client verification during initial check
        # This prevents the "Unauthorized" error handling issue
        true
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
              redirect_uri: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
              scope: SCOPES,
            },
          )
        return nil unless token_response
        credentials[:access_token] = token_response[:access_token]

        credentials
      end

      def on_verify_client_failure
        client.destroy!
      end

      def get_authorize_url
        return nil unless client

        uri = DiscourseActivityPub::URI.parse("https://#{domain}/#{AUTHORIZE_PATH}")
        uri.query =
          ::URI.encode_www_form(
            client_id: client.credentials["client_id"],
            response_type: "code",
            redirect_uri: "#{DiscourseActivityPub.base_url}/#{REDIRECT_PATH}",
            scopes: SCOPES,
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

      protected

      def is_gotosocial_instance?(nodeinfo_response)
        # Verify it's a valid nodeinfo response
        return false unless nodeinfo_response.is_a?(Hash)
        return false unless nodeinfo_response[:links].is_a?(Array)
        return false if nodeinfo_response[:links].empty?

        # Get the actual nodeinfo data to check software
        nodeinfo_link = nodeinfo_response[:links].find { |link| link[:rel]&.include?("nodeinfo") }
        return false unless nodeinfo_link

        nodeinfo_href = nodeinfo_link[:href]
        return false unless nodeinfo_href

        # Fetch the actual nodeinfo data
        nodeinfo_data = request(nodeinfo_href.sub("https://#{domain}/", ""), verb: :get)
        return false unless nodeinfo_data

        # Check if software name is GoToSocial
        nodeinfo_data.dig(:software, :name)&.downcase == "gotosocial"
      rescue StandardError
        false
      end
    end
  end
end
