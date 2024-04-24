# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class Discourse < Authorization
      SCOPE = "read"
      FIND_ACTOR_BY_USER_PATH = "ap/actor/find-by-user"

      def platform_store_key
        "discourse"
      end

      def verify
        if !verify_redirect
          add_error(I18n.t("discourse_activity_pub.auth.error.failed_to_verify_redirect"))
          return false
        end
        !!create_app
      end

      def create_app
        app = get_app
        return app if app

        save_app(client_id: DiscourseActivityPub.base_url, pem: OpenSSL::PKey::RSA.new(2048).export)
        get_app
      end

      def get_authorize_url
        app = get_app
        return unless app && app.pem

        uri = DiscourseActivityPub::URI.parse("https://#{domain}/user-api-key/new")
        return unless uri

        nonce = app.nonce || generate_nonce(app)
        rsa = OpenSSL::PKey::RSA.new(app.pem)

        params = {
          public_key: rsa.public_key,
          client_id: app.client_id,
          nonce: nonce,
          auth_redirect: auth_redirect,
          application_name: SiteSetting.title,
          scopes: SCOPE,
        }
        uri.query = ::URI.encode_www_form(params)
        uri.to_s
      end

      def verify_redirect
        params = { auth_redirect: auth_redirect }
        path = "ap/auth/verify-redirect"
        request(path, verb: :get, params: params)
      end

      def auth_redirect
        "#{DiscourseActivityPub.base_url}/ap/auth/redirect/discourse"
      end

      def get_token(params)
        payload = params[:payload]
        return unless payload

        data = decrypt_payload(payload)
        return false unless data.is_a?(Hash) && data[:key]

        data[:key]
      end

      def decrypt_payload(payload)
        app = get_app
        return false unless app.present? && app.pem

        rsa = OpenSSL::PKey::RSA.new(app.pem)
        decrypted_payload = rsa.private_decrypt(Base64.decode64(payload))
        return false unless decrypted_payload.present?

        begin
          data = JSON.parse(decrypted_payload).symbolize_keys
        rescue JSON::ParserError
          return false
        end

        nonce = app.nonce
        destroy_nonce(app)
        return false unless data[:nonce] == nonce

        data
      end

      def generate_nonce(app)
        nonce = SecureRandom.hex(32)

        save_app(client_id: app.client_id, pem: app.pem, nonce: nonce)

        nonce
      end

      def destroy_nonce(app)
        save_app(client_id: app.client_id, pem: app.pem, nonce: nil)
      end

      def get_actor_id(key)
        actor_json = get_actor(key)
        actor_json && actor_json["id"]
      end

      def get_actor(key)
        request(FIND_ACTOR_BY_USER_PATH, verb: :get, headers: { "User-Api-Key" => "#{key}" })
      end
    end
  end
end
