# frozen_string_literal: true

module DiscourseActivityPub
  class AuthorizationController < ApplicationController
    DOMAIN_SESSION_KEY = "activity_pub_authorize_domain"
    AUTHORIZATION_SESSION_KEY = "activity_pub_authorize_id"
    NONCE_SESSION_KEY = "activity_pub_authorize_nonce"
    SESSION_EXPIRY_MINUTES = 10

    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_site_enabled
    before_action :ensure_logged_in, except: %i[verify_redirect]
    before_action :validate_domain, only: %i[verify]
    before_action :validate_auth_type, only: %i[verify authorize]
    before_action :ensure_domain_session, only: %i[authorize]
    before_action :create_authorization, only: %i[authorize]
    before_action :ensure_authorization_session, only: %i[redirect]
    before_action :ensure_authorization, only: %i[redirect]

    skip_before_action :preload_json, :check_xhr, only: %i[redirect verify_redirect]

    rescue_from DiscourseActivityPub::AuthFailed do |e|
      @authorization.destroy! if @authorization.present?
      redirect_to "/u/#{current_user.username}/preferences/activity-pub?error=#{CGI.escape(e.message)}"
    end

    def index
      render_serialized(
        current_user.activity_pub_authorizations,
        DiscourseActivityPub::AuthorizationSerializer,
        root: "authorizations",
      )
    end

    def verify
      auth_handler.verify

      if auth_handler.success?
        set_session_value(DOMAIN_SESSION_KEY, @domain)
        render json: success_json.merge(domain: @domain)
      else
        render_json_error(auth_handler.errors.full_messages.join("\n"), status: 422)
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
      set_session_value(AUTHORIZATION_SESSION_KEY, @authorization.id)

      authorize_url = auth_handler.get_authorize_url
      if authorize_url
        set_session_value(NONCE_SESSION_KEY, auth_handler.nonce) if @authorization.discourse?
        redirect_to authorize_url, allow_other_host: true
      else
        render_auth_error("invalid_domain", 404)
      end
    end

    def redirect
      @authorization.token = auth_handler.get_token(redirect_params)
      raise_auth_failed unless @authorization.token

      actor_ap_id = auth_handler.get_actor_ap_id(@authorization.token)
      raise_auth_failed unless actor_ap_id

      actor = DiscourseActivityPubActor.find_by_ap_id(actor_ap_id)
      raise_auth_failed unless actor

      ActiveRecord::Base.transaction do
        DiscourseActivityPubAuthorization.where(actor_id: actor.id).destroy_all

        @authorization.actor_id = actor.id
        @authorization.save!
      end

      if actor.model.is_a?(User) && actor.model&.staged?
        Jobs.enqueue(
          :merge_user,
          user_id: actor.model.id,
          target_user_id: current_user.id,
          current_user_id: current_user.id,
        )
      end

      redirect_to "/u/#{current_user.username}/preferences/activity-pub"
    end

    def destroy
      params.require(:auth_id)

      authorization = DiscourseActivityPubAuthorization.find_by(id: params[:auth_id])
      if authorization && authorization.destroy!
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    protected

    def render_auth_error(key, status)
      render_json_error(I18n.t("discourse_activity_pub.auth.error.#{key}"), status)
    end

    def raise_auth_failed
      message =
        (
          if auth_handler.errors.full_messages.present?
            auth_handler.errors.full_messages.join("\n")
          else
            I18n.t("discourse_activity_pub.auth.error.failed_to_authorize")
          end
        )
      raise DiscourseActivityPub::AuthFailed.new(message)
    end

    def auth_handler
      @auth_handler ||=
        "DiscourseActivityPub::Auth::#{@auth_type.to_s.classify}".constantize.new(
          auth_id: @auth_id,
          domain: @domain,
        )
    end

    def validate_auth_type
      params.require(:auth_type)
      @auth_type = params[:auth_type].to_sym
      unless DiscourseActivityPubAuthorization.auth_types.keys.include?(@auth_type)
        raise ::Discourse::InvalidParameters
      end
    end

    def validate_domain
      params.require(:domain)
      @domain = params[:domain]
      unless DiscourseActivityPub::URI::DOMAIN_REGEX.match?(@domain)
        raise ::Discourse::InvalidParameters
      end
    end

    def ensure_domain_session
      @domain = get_session_value(DOMAIN_SESSION_KEY)
      unless @domain
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.session_expired"),
              )
      end
    end

    def create_authorization
      @authorization =
        DiscourseActivityPubAuthorization.create!(
          domain: @domain,
          user_id: current_user.id,
          auth_type: DiscourseActivityPubAuthorization.auth_types[@auth_type.to_sym],
        )
      unless @authorization
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.authorization_required"),
              )
      end
      @auth_id = @authorization.id
    end

    def ensure_authorization_session
      @auth_id = get_session_value(AUTHORIZATION_SESSION_KEY)
      unless @auth_id
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.session_expired"),
              )
      end
    end

    def ensure_authorization
      @authorization = DiscourseActivityPubAuthorization.find_by(id: @auth_id)
      unless @authorization
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.authorization_required"),
              )
      end
      @auth_type = @authorization.auth_type_name
      @domain = @authorization.domain
    end

    def get_session_value(key)
      secure_session[key]
    end

    def set_session_value(key, value)
      secure_session.set(key, value, expires: SESSION_EXPIRY_MINUTES.minutes)
    end

    def redirect_params
      result = params.permit(:code, :payload).to_h.symbolize_keys
      result[:nonce] = get_session_value(NONCE_SESSION_KEY) if @authorization.discourse?
      result
    end
  end
end
