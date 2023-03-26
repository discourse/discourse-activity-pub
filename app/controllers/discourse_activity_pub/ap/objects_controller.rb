# frozen_string_literal: true

class DiscourseActivityPub::AP::ObjectsController < ApplicationController
  include DiscourseActivityPub::JsonLd

  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

  before_action :rate_limit
  before_action :ensure_site_enabled
  before_action :validate_headers

  protected

  def rate_limit
    limit = SiteSetting.activity_pub_rate_limit_get_objects_per_minute
    RateLimiter.new(nil, "activity-pub-object-get-min-#{request.remote_ip}", limit, 1.minute).performed!
  end

  rescue_from RateLimiter::LimitExceeded do
    render_json_error I18n.t("rate_limiter.slow_down"), status: 429
  end

  def ensure_site_enabled
    render_activity_error("not_enabled", 403) unless Site.activity_pub_enabled
  end

  def validate_headers
    render_activity_error("json_not_valid", 422) unless valid_content_type?(request.headers['Content-Type'])
  end

  def render_activity_error(key, status)
    render_json_error I18n.t("discourse_activity_pub.activity.error.#{key}"), status: status
  end
end
