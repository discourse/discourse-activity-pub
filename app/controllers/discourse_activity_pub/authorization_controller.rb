# frozen_string_literal: true

module DiscourseActivityPub
  class AuthorizationController < ApplicationController
    DOMAIN_SESSION_KEY = "activity_pub_authorize_domain"
    AUTHORIZATION_SESSION_KEY = "activity_pub_authorize_id"
    STATE_SESSION_KEY = "activity_pub_authorize_state"
    SESSION_EXPIRY_MINUTES = 10
    SUPPORTED_AUTH_TYPES = %i[mastodon]

    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_site_enabled
    before_action :ensure_logged_in
    before_action :validate_domain, only: %i[verify]
    before_action :validate_auth_type, only: %i[verify authorize redirect]
    before_action :ensure_domain_session, only: %i[authorize]
    before_action :ensure_client, only: %i[authorize]
    before_action :create_authorization, only: %i[authorize]

    skip_before_action :preload_json, :check_xhr, only: %i[redirect]

    rescue_from DiscourseActivityPub::AuthFailed do |e|
      @authorization&.destroy!
      clear_authorization_session
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
      auth_handler.verify_client

      if auth_handler.success?
        set_session_value(DOMAIN_SESSION_KEY, @domain)
        render json: success_json.merge(domain: @domain)
      else
        render_json_error(auth_handler.errors.full_messages.join("\n"), status: 422)
      end
    end

    def authorize
      state = SecureRandom.hex(32)
      set_session_value(AUTHORIZATION_SESSION_KEY, @authorization.id)
      set_session_value(STATE_SESSION_KEY, state)
      auth_handler.state = state

      authorize_url = auth_handler.get_authorize_url
      if authorize_url
        redirect_to authorize_url, allow_other_host: true
      else
        clear_authorization_session
        render_auth_error("invalid_domain", 404)
      end
    end

    def redirect
      ensure_authorization_session
      ensure_authorization
      ensure_authorization_state

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

      clear_authorization_session
      redirect_to "/u/#{current_user.username}/preferences/activity-pub"
    end

    def destroy
      params.require(:auth_id)

      authorization =
        DiscourseActivityPubAuthorization.find_by(id: params[:auth_id], user_id: current_user.id)
      if authorization && authorization.destroy!
        render json: success_json
      else
        render json: failed_json, status: :not_found
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
        "DiscourseActivityPub::Auth::#{@auth_type.to_s.classify}".constantize.new(domain: @domain)
    end

    def validate_auth_type
      params.require(:auth_type)
      @auth_type = params[:auth_type].to_sym
      if SUPPORTED_AUTH_TYPES.exclude?(@auth_type)
        clear_authorization_session if action_name == "redirect"
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

    def ensure_client
      @client =
        DiscourseActivityPubClient.find_by(
          domain: @domain,
          auth_type: DiscourseActivityPubClient.auth_types[@auth_type.to_sym],
        )
      raise ::Discourse::InvalidParameters.new unless @client
    end

    def create_authorization
      @authorization =
        DiscourseActivityPubAuthorization.create!(client_id: @client.id, user_id: current_user.id)
      unless @authorization
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.authorization_required"),
              )
      end
      auth_handler.auth_id = @authorization.id
    end

    def ensure_authorization_session
      @auth_id = get_session_value(AUTHORIZATION_SESSION_KEY)
      unless @auth_id
        clear_authorization_session
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.session_expired"),
              )
      end
    end

    def ensure_authorization
      @authorization =
        DiscourseActivityPubAuthorization.find_by(id: @auth_id, user_id: current_user.id)
      unless @authorization
        clear_authorization_session
        raise ::Discourse::InvalidAccess.new(
                I18n.t("discourse_activity_pub.auth.error.authorization_required"),
              )
      end
      @auth_type = @authorization.client.auth_type_name
      if SUPPORTED_AUTH_TYPES.exclude?(@auth_type)
        clear_authorization_session
        raise ::Discourse::InvalidParameters
      end
      @domain = @authorization.client.domain
      auth_handler.auth_id = @authorization.id
    end

    def ensure_authorization_state
      expected_state = get_session_value(STATE_SESSION_KEY)
      state = params[:state].to_s
      state_matches =
        expected_state.present? && state.present? && state.bytesize == expected_state.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(state, expected_state)

      raise_invalid_redirect_params unless state_matches
    end

    def raise_invalid_redirect_params
      raise DiscourseActivityPub::AuthFailed.new(
              I18n.t("discourse_activity_pub.auth.error.invalid_redirect_params"),
            )
    end

    def get_session_value(key)
      server_session[key]
    end

    def set_session_value(key, value)
      server_session.set(key, value, expires: SESSION_EXPIRY_MINUTES.minutes)
    end

    def clear_authorization_session
      server_session.delete(AUTHORIZATION_SESSION_KEY)
      server_session.delete(STATE_SESSION_KEY)
    end

    def redirect_params
      params.permit(:code).to_h.symbolize_keys
    end
  end
end
