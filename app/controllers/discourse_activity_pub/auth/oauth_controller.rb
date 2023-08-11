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
          redirect_to authorize_url, allow_other_host: true
        else
          render_auth_error("invalid_oauth_domain", 404)
        end
      end

      def redirect
        params.require(:code)
        domain = secure_session[AUTHORIZE_DOMAIN_KEY]

        raise Discourse::InvalidAccess.new(
          I18n.t("discourse_activity_pub.auth.error.oauth_session_expired")
        ) unless domain

        access_token = OAuth.get_token(domain, params[:code])

        raise Discourse::InvalidAccess.new(
          I18n.t("discourse_activity_pub.auth.error.failed_to_authorize")
        ) unless access_token

        current_user.activity_pub_save_access_token(domain, access_token)

        actor_id = OAuth.get_actor_id(domain, access_token)

        raise Discourse::NotFound.new(
          I18n.t("discourse_activity_pub.auth.error.failed_to_get_actor")
        ) unless actor_id

        current_user.activity_pub_save_actor_id(domain, actor_id)

        user = DiscourseActivityPub::UserHandler.find_user_by_stored_actor_id(actor_id)

        if user
          Jobs.enqueue(
            :merge_user,
            user_id: user.id,
            target_user_id: current_user.id,
            current_user_id: current_user.id,
          )
        end

        redirect_to "/u/#{current_user.username}/activity-pub"
      end
    end
  end
end