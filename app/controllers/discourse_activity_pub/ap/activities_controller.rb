# frozen_string_literal: true

class DiscourseActivityPub::AP::ActivitiesController < DiscourseActivityPub::AP::ObjectsController
  before_action :ensure_activity_exists
  before_action :ensure_can_access_base_object

  def show
    render json: @activity.ap.json
  end

  protected

  def ensure_activity_exists
    unless @activity = DiscourseActivityPubActivity.find_by(ap_key: params[:key])
      render_activity_pub_error("not_found", 404)
    end
  end

  def ensure_can_access_base_object
    unless !@activity.base_object || guardian.can_see?(@activity.base_object.model)
      render_activity_pub_error("not_available", 401)
    end
  end
end
