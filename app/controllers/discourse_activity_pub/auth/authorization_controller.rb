# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class AuthorizationController < AuthController
      skip_before_action :ensure_logged_in, only: %i[redirect verify_redirect]
      skip_before_action :preload_json, :check_xhr, only: %i[redirect verify_redirect]
      before_action :ensure_domain, only: %i[authorize redirect]
      before_action :ensure_authorization, only: %i[authorize redirect]

      AUTHORIZE_DOMAIN_KEY = "activity_pub_authorize_domain"
      SESSION_EXPIRY_MINUTES = 10

      def verify
        params.require(:domain)
        @domain = params[:domain]

        ensure_authorization

        if @authorization.verify
          set_session_domain(@authorization.domain)
          render json: success_json.merge(domain: @authorization.domain)
        else
          render_json_error(@authorization.errors.full_messages.join("\n"), status: 422)
        end
      end

      def verify_redirect
        params.require(:auth_redirect)

        if UserApiKey.invalid_auth_redirect?(CGI.unescape(params[:auth_redirect]))
          render_auth_error("invalid_auth_redirect", 403)
        else
          render json: success_json
        end
      end

      def authorize
        authorize_url = @authorization.get_authorize_url

        if authorize_url
          redirect_to authorize_url, allow_other_host: true
        else
          render_auth_error("invalid_domain", 404)
        end
      end

      def redirect
        access_token = @authorization.get_token(redirect_params)
        unless access_token
          raise ::Discourse::InvalidAccess.new(
                  I18n.t("discourse_activity_pub.auth.error.failed_to_authorize"),
                )
        end
        current_user.activity_pub_save_access_token(@domain, access_token)

        actor_id = @authorization.get_actor_id(access_token)

        if actor_id
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
        end

        redirect_to "/u/#{current_user.username}/preferences/activity-pub"
      end

      def destroy
        params.require(:actor_id)

        if current_user.activity_pub_remove_actor_id(params[:actor_id])
          render json: success_json
        else
          render json: failed_json, status: 422
        end
      end

      protected

      def ensure_authorization
        params.require(:platform)
        auth_klass = "DiscourseActivityPub::Auth::#{params[:platform].classify}"
        raise ::Discourse::InvalidParameters unless class_exists?(auth_klass)
        @authorization = auth_klass.constantize.new(domain: @domain)
      end

      def ensure_domain
        @domain = secure_session[AUTHORIZE_DOMAIN_KEY]

        unless @domain
          raise ::Discourse::InvalidAccess.new(
                  I18n.t("discourse_activity_pub.auth.error.session_expired"),
                )
        end
      end

      def set_session_domain(domain)
        secure_session.set(AUTHORIZE_DOMAIN_KEY, domain, expires: SESSION_EXPIRY_MINUTES.minutes)
      end

      def class_exists?(class_name)
        klass = Module.const_get(class_name)
        klass.is_a?(Class)
      rescue NameError
        false
      end

      def redirect_params
        params.permit(:code, :payload).to_h.symbolize_keys
      end
    end
  end
end
