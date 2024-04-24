# frozen_string_literal: true

module DiscourseActivityPub
  class ActorController < ApplicationController
    PAGE_SIZE = 50
    ORDER = %w[actor user followed_at]

    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_admin, only: %i[follow unfollow find_by_handle]
    before_action :ensure_site_enabled
    before_action :ensure_user_api, only: %i[find_by_user]
    before_action :find_actor
    before_action :ensure_model_enabled
    before_action :ensure_can_access
    before_action :find_target_actor, only: %i[follow unfollow]

    def show
      render_serialized(@actor, DiscourseActivityPub::ActorSerializer, include_model: true)
    end

    def follow
      if !@actor.can_follow?(@target_actor)
        return render_actor_error("cant_follow_target_actor", 401)
      end

      if FollowHandler.follow(@actor.id, @target_actor.id)
        render json: success_json
      else
        render json: failed_json
      end
    end

    def unfollow
      if !@actor.following?(@target_actor)
        return render_actor_error("not_following_target_actor", 404)
      end

      if FollowHandler.unfollow(@actor.id, @target_actor.id)
        render json: success_json
      else
        render json: failed_json
      end
    end

    def find_by_handle
      params.require(:handle)

      handle_actor = DiscourseActivityPubActor.find_by_handle(params[:handle])

      if handle_actor
        handle_actor_follow = handle_actor.follow_followers.find_by(follower_id: @actor.id)
        handle_actor.followed_at = handle_actor_follow.followed_at if handle_actor_follow

        render_serialized(handle_actor, DiscourseActivityPub::ActorSerializer)
      else
        render json: failed_json
      end
    end

    def follows
      guardian.ensure_can_admin!(@actor)

      actors.each { |actor| actor.followed_at = actor.follow_followers&.first&.followed_at }

      render_actors
    end

    def followers
      guardian.ensure_can_see!(@actor.model)

      actors.each { |actor| actor.followed_at = actor.follow_follows&.first&.followed_at }

      render_actors
    end

    def find_by_user
      if current_user.present? && current_user.activity_pub_actor.present?
        render json: current_user.activity_pub_actor.ap.json
      else
        render json: failed_json, status: 404
      end
    end

    protected

    def render_actors
      render_json_dump(
        actors: serialize_data(actors, ActorSerializer, root: false, include_model: true),
        meta: {
          total: @total,
          load_more_url: load_more_url(@page),
        },
      )
    end

    def actors
      @actors ||=
        begin
          actors =
            self
              .send("#{action_name}_actors")
              .left_joins(:user)
              .order("#{order_table}.#{order} #{params[:asc] ? "ASC" : "DESC"} NULLS LAST")

          limit = fetch_limit_from_params(default: PAGE_SIZE, max: PAGE_SIZE)
          @page = fetch_int_from_params(:page, default: 0)
          @total = actors.count

          actors.limit(limit).offset(limit * @page).to_a
        end
    end

    def follows_actors
      @follows_actors ||= @actor.follows
    end

    def followers_actors
      @followers_actors ||= @actor.followers
    end

    def permitted_order
      @permitted_order ||= ORDER.find { |attr| attr == params[:order] }
    end

    def order_table
      case permitted_order
      when "actor"
        "discourse_activity_pub_actors"
      when "user"
        "users"
      when "followed_at"
        "discourse_activity_pub_follows"
      else
        "discourse_activity_pub_follows"
      end
    end

    def order
      case permitted_order
      when "actor"
        "username"
      when "user"
        "username"
      when "followed_at"
        "created_at"
      else
        "created_at"
      end
    end

    def load_more_url(page)
      load_more_params = params.slice(:order, :asc).permit!
      load_more_params[:page] = page + 1
      load_more_uri = ::URI.parse("/ap/actor/#{params[:actor_id]}/followers.json")
      load_more_uri.query = ::URI.encode_www_form(load_more_params.to_h)
      load_more_uri.to_s
    end

    def ensure_model_enabled
      render_not_enabled unless @actor.model&.activity_pub_enabled
    end

    def ensure_can_access
      return true if guardian.can_admin?(@actor)
      render_not_enabled unless DiscourseActivityPub.publishing_enabled
    end

    def find_actor
      @actor = DiscourseActivityPubActor.find_by_id(params.require(:actor_id))
      render_actor_error("actor_not_found", 404) unless @actor.present?
    end

    def find_target_actor
      @target_actor = DiscourseActivityPubActor.find_by_id(params[:target_actor_id])
      render_actor_error("target_actor_not_found", 404) unless @target_actor.present?
    end

    def ensure_user_api
      render_actor_error("user_not_authorized", 403) unless is_user_api?
    end

    def render_actor_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.actor.error.#{key}"), status: status
    end
  end
end
