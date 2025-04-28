# frozen_string_literal: true

class DiscourseActivityPub::AP::CollectionsController < DiscourseActivityPub::AP::ObjectsController
  before_action :ensure_collection_exists
  before_action :ensure_can_access_collection

  def show
    render_activity_json(@collection.ap.json)
  end

  protected

  def ensure_collection_exists
    unless @collection = DiscourseActivityPubCollection.find_by(ap_key: params[:key], local: true)
      render_activity_pub_error("not_found", 404)
    end
  end

  def ensure_can_access_collection
    render_activity_pub_error("not_available", 401) unless guardian.can_see?(@collection.model)
  end
end
