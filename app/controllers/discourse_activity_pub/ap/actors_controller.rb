# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorsController < DiscourseActivityPub::AP::ObjectsController
  before_action :ensure_actor_exists
  before_action :ensure_can_access_actor
  before_action :ensure_can_access_actor_model
  before_action :ensure_actor_ready

  def show
    if browser_request?
      redirect_to @actor.model.activity_pub_url
    else
      render_activity_json(@actor.ap.json)
    end
  end

  protected

  def ensure_actor_exists
    unless @actor = DiscourseActivityPubActor.find_by(ap_key: params[:key])
      render_activity_pub_error("not_found", 404)
    end
  end

  def ensure_can_access_actor
    unless (DiscourseActivityPub.publishing_enabled || @actor.ap.group? || @actor.ap.application?)
      render_activity_pub_error("not_available", 401)
    end
  end

  def ensure_can_access_actor_model
    return true if @actor.ap.application?
    render_activity_pub_error("not_available", 401) unless guardian.can_see?(@actor.model)
  end

  def ensure_actor_ready
    unless @actor.ready? && DiscourseActivityPub::ActorHandler.ensure_required_attributes(@actor)
      render_activity_pub_error("not_available", 403)
    end
  end
end
