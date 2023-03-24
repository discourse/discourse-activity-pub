# frozen_string_literal: true

class DiscourseActivityPub::AP::ActorsController < DiscourseActivityPub::AP::ObjectsController
  before_action :ensure_model_exists
  before_action :ensure_can_access_model
  before_action :ensure_model_ready

  def show
    render json: @model.activity_pub_actor.ap.json
  end

  protected

  def ensure_model_exists
    render_activity_error("not_found", 404) unless @model = DiscourseActivityPub::Model.find_by_url(request.original_url)
  end

  def ensure_can_access_model
    render_activity_error("not_available", 401) unless guardian.can_see?(@model)
  end

  def ensure_model_ready
    render_activity_error("not_available", 403) unless DiscourseActivityPub::Model.ready?(@model)
  end
end
