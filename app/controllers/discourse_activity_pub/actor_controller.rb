# frozen_string_literal: true

module DiscourseActivityPub
  class ActorController < ApplicationController
    before_action :ensure_admin
    before_action :ensure_site_enabled
    before_action :find_actor
    before_action :find_follow_actor, only: [:follow]

    def follow
      if !@actor.can_follow?(@follow_actor)
        return render_actor_error("cant_follow", 401)
      end

      if FollowHandler.perform(@actor.id, @follow_actor.id)
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
      return render_actor_error("actor_not_found", 404) unless @actor.present?
    end

    def find_follow_actor
      @follow_actor = DiscourseActivityPubActor.find_by_id(params[:follow_actor_id])
      return render_actor_error("follow_actor_not_found", 404) unless @follow_actor.present?
    end

    def ensure_site_enabled
      render_actor_error("not_enabled", 403) unless DiscourseActivityPub.enabled
    end

    def render_actor_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.actor.error.#{key}"), status: status
    end
  end
end