# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class OAuthController < AuthController
      skip_before_action :preload_json, :check_xhr, only: [:redirect]

      AUTHORIZE_DOMAIN_KEY = "activity_pub_authorize_domain"

      def create
        params.require(:domain)

        oauth = OAuth.new(params[:domain])
        app = oauth.create_app

        if oauth.errors.any?
          render_json_error(oauth.errors.full_messages.join("\n"), status: 422)
        else
          render json: success_json.merge(domain: app.domain)
        end
      end

      def authorize
        params.require(:domain)

        authorize_url = OAuth.get_authorize_url(params[:domain])

        if authorize_url
          secure_session.set(AUTHORIZE_DOMAIN_KEY, params[:domain], expires: 10.minutes)
          redirect_to authorize_url
        else
          render_oauth_error("invalid_oauth_domain", 404)
        end
      end

      def redirect
        params.require(:code)
        domain = secure_session.get(AUTHORIZE_DOMAIN_KEY)

        raise Discourse::InvalidAccess.new(
          I18n.t("discourse_activity_pub.oauth.error.oauth_session_expired")
        ) unless domain

        access_token = OAuth.get_token(domain, code)

        raise Discourse::InvalidAccess.new(
          I18n.t("discourse_activity_pub.oauth.error.failed_to_authorize")
        ) unless domain

        current_user.activity_pub_save_access_token(domain, access_token)

        redirect_to "/u/#{current_user.username}/activity-pub"
      end
    end
  end
end