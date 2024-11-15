# frozen_string_literal: true

module DiscourseActivityPub
  class Auth
    class Discourse < Auth
      FIND_ACTOR_BY_USER_PATH = "ap/local/actor/find-by-user"
      CLIENT_PATH = "user-api-key-client"

      def name
        "discourse"
      end

      def check_client
        request(
          "#{CLIENT_PATH}?client_id=#{DiscourseActivityPubActor.application.ap_id}",
          verb: :head,
        )
      end

      def register_client
        keypair = OpenSSL::PKey::RSA.new(2048)
        private_key = keypair.to_pem
        public_key = keypair.public_key.to_pem

        response =
          request(
            CLIENT_PATH,
            verb: :post,
            body: {
              public_key: public_key,
              client_id: DiscourseActivityPubActor.application.ap_id,
              application_name: SiteSetting.title,
              auth_redirect: auth_redirect,
              scopes: DiscourseActivityPubClient::DISCOURSE_SCOPE,
            },
          )
        return nil unless response && response["success"]

        { public_key: public_key, private_key: private_key }
      end

      def nonce
        @nonce ||= secure_random_hex(32)
      end

      def get_authorize_url
        uri = DiscourseActivityPub::URI.parse("https://#{domain}/user-api-key/new")
        params = {
          public_key: client.credentials[:public_key],
          client_id: client_id,
          nonce: nonce,
          auth_redirect: auth_redirect,
          application_name: SiteSetting.title,
          scopes: DiscourseActivityPubClient::DISCOURSE_SCOPE,
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

      def client_id
        @client_id ||= DiscourseActivityPubActor.application.ap_id
      end

      def auth_redirect
        @auth_redirect ||= "#{DiscourseActivityPub.base_url}/ap/auth/redirect/discourse"
      end

      def decrypt_payload(params = {})
        rsa = OpenSSL::PKey::RSA.new(authorization.client.credentials["private_key"])
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
