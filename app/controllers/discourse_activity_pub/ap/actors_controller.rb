# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorsController < DiscourseActivityPub::AP::ObjectsController
  before_action :ensure_actor_exists
  before_action :ensure_can_access_actor
  before_action :ensure_model_ready

  def show
    render json: @actor.ap.json
  end

  protected

  def ensure_actor_exists
    render_activity_error("not_found", 404) unless @actor = DiscourseActivityPubActor.find_by(ap_key: params[:key])
  end

  def ensure_can_access_actor
    render_activity_error("not_available", 401) unless guardian.can_see?(@actor.model)
  end

  def ensure_model_ready
    render_activity_error("not_available", 403) unless DiscourseActivityPub::Model.ready?(@actor.model)
  end
end