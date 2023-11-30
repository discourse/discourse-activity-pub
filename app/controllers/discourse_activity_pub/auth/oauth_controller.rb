# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class OAuthController < AuthController
      skip_before_action :preload_json, :check_xhr, only: [:redirect]

      before_action :get_domain, only: %i[authorize redirect]

      AUTHORIZE_DOMAIN_KEY = "activity_pub_authorize_domain"
      SESSION_EXPIRY_MINUTES = 10

      def verify
        params.require(:domain)

        oauth = OAuth.new(params[:domain])
        app = oauth.create_app

        if oauth.errors.any?
          render_json_error(oauth.errors.full_messages.join("\n"), status: 422)
        else
          set_domain(app.domain)
          render json: success_json.merge(domain: app.domain)
        end
      end

      def authorize
        authorize_url = OAuth.get_authorize_url(@domain)

        if authorize_url
          redirect_to authorize_url, allow_other_host: true
        else
          render_auth_error("invalid_oauth_domain", 404)
        end
      end

      def redirect
        params.require(:code)

        access_token = OAuth.get_token(@domain, params[:code])

        unless access_token
          raise Discourse::InvalidAccess.new(
                  I18n.t("discourse_activity_pub.auth.error.failed_to_authorize"),
                )
        end

        current_user.activity_pub_save_access_token(@domain, access_token)

        actor_id = OAuth.get_actor_id(@domain, access_token)

        unless actor_id
          raise Discourse::NotFound.new(
                  I18n.t("discourse_activity_pub.auth.error.failed_to_get_actor"),
                )
        end

        current_user.activity_pub_save_actor_id(@domain, actor_id)

        user = DiscourseActivityPub::UserHandler.find_user_by_stored_actor_id(actor_id)

        if user
          Jobs.enqueue(
            :merge_user,
            user_id: user.id,
            target_user_id: current_user.id,
            current_user_id: current_user.id,
          )
        end

        redirect_to "/u/#{current_user.username}/preferences/activity-pub"
      end

      protected

      def get_domain
        @domain = secure_session[AUTHORIZE_DOMAIN_KEY]

        unless @domain
          raise Discourse::InvalidAccess.new(
                  I18n.t("discourse_activity_pub.auth.error.oauth_session_expired"),
                )
        end
      end

      def set_domain(domain)
        secure_session.set(AUTHORIZE_DOMAIN_KEY, domain, expires: SESSION_EXPIRY_MINUTES.minutes)
      end
    end
  end
end
