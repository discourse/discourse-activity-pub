# frozen_string_literal: true

class DiscourseActivityPub::AP::ActivitiesController < DiscourseActivityPub::AP::ObjectsController
  before_action :ensure_activity_exists

  def show
    render json: @activity.ap.json
  end

  protected

  def ensure_activity_exists
    render_activity_error("not_found", 404) unless @activity = DiscourseActivityPubActivity.find_by(ap_key: params[:key])
  end
end
