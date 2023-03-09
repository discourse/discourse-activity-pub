# frozen_string_literal: true

class DiscourseActivityPub::AP::CollectionsController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

  before_action :rate_limit
  before_action :ensure_site_enabled
  before_action :ensure_model
  before_action :ensure_can_access
  before_action :ensure_model_enabled

  protected

  def rate_limit
  end

  rescue_from RateLimiter::LimitExceeded do
    render_json_error I18n.t("rate_limiter.slow_down"), status: 429
  end

  def ensure_site_enabled
    render_ap_error("not_enabled", 403) unless SiteSetting.activity_pub_enabled && !SiteSetting.login_required
  end

  def ensure_model
    render_ap_error("not_found", 404) unless @model = DiscourseActivityPub::Model.find_by_url(request.original_url)
  end

  def ensure_can_access
    render_ap_error("not_available", 401) unless guardian.can_see?(@model)
  end

  def ensure_model_enabled
    render_ap_error("not_enabled", 403) unless DiscourseActivityPub::Model.enabled?(@model)
  end

  def render_ap_error(key, status)
    render_json_error I18n.t("discourse_activity_pub.activity.error.#{key}"), status: status
  end
end
