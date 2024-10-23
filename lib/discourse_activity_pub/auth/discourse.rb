# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    class Discourse < Auth
      SCOPE = "read"
      FIND_ACTOR_BY_USER_PATH = "ap/local/actor/find-by-user"

      def verify
        unless verify_redirect
          auth_error("failed_to_verify_redirect", auth_redirect: auth_redirect, domain: domain)
        end
      end

      def nonce
        @nonce ||= secure_random_hex(32)
      end

      def get_authorize_url
        return auth_error("authorization_required") unless authorization

        uri = DiscourseActivityPub::URI.parse("https://#{domain}/user-api-key/new")
        rsa = OpenSSL::PKey::RSA.new(authorization.private_key)
        params = {
          public_key: rsa.public_key,
          client_id: client_id,
          nonce: nonce,
          auth_redirect: auth_redirect,
          application_name: SiteSetting.title,
          scopes: SCOPE,
        }
        uri.query = ::URI.encode_www_form(params)
        uri.to_s
      end

      def get_token(params = {})
        return auth_error("invalid_redirect_params") unless params[:payload]
        return auth_error("authorization_required") unless authorization

        data = decrypt_payload(params)
        return false unless data.is_a?(Hash) && data[:key]

        data[:key]
      end

      def get_actor_ap_id(key)
        actor_json = get_actor(key)
        return auth_error("failed_to_get_actor") unless actor_json
        actor_json["id"]
      end

      protected

      def verify_redirect
        params = { auth_redirect: auth_redirect }
        path = "ap/auth/verify-redirect"
        request(path, verb: :get, params: params)
      end

      def client_id
        @client_id ||= "#{DiscourseActivityPub.host}-activity-pub-#{secure_random_hex(16)}"
      end

      def auth_redirect
        @auth_redirect ||= "#{DiscourseActivityPub.base_url}/ap/auth/redirect/discourse"
      end

      def decrypt_payload(params = {})
        rsa = OpenSSL::PKey::RSA.new(authorization.private_key)
        decrypted_payload = rsa.private_decrypt(Base64.decode64(params[:payload]))

        return auth_error("failed_to_decrypt_payload") unless decrypted_payload

        begin
          data = JSON.parse(decrypted_payload).symbolize_keys
        rescue JSON::ParserError
          return auth_error("failed_to_decrypt_payload")
        end

        return auth_error("failed_to_verify_nonce") unless data[:nonce] == params[:nonce]

        data
      end

      def get_actor(key)
        request(FIND_ACTOR_BY_USER_PATH, verb: :get, headers: { "User-Api-Key" => "#{key}" })
      end

      def secure_random_hex(bytes)
        Rails.env.test? ? ENV["ACTIVITY_PUB_TEST_RANDOM_HEX"] : SecureRandom.hex(bytes)
      end
    end
  end
end
