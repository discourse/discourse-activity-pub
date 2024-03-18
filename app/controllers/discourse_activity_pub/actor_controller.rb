# frozen_string_literal: true

module DiscourseActivityPub
  class ActorController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerfication

    before_action :ensure_admin
    before_action :ensure_site_enabled
    before_action :find_actor
    before_action :find_target_actor, only: %i[follow unfollow]

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

    protected

    def find_actor
      @actor = DiscourseActivityPubActor.find_by_id(params.require(:actor_id))
      render_actor_error("actor_not_found", 404) unless @actor.present?
    end

    def find_target_actor
      @target_actor = DiscourseActivityPubActor.find_by_id(params[:target_actor_id])
      render_actor_error("target_actor_not_found", 404) unless @target_actor.present?
    end

    def render_actor_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.actor.error.#{key}"), status: status
    end
  end
end
