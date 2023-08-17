# frozen_string_literal: true

class DiscourseActivityPub::AP::ObjectsController < ApplicationController
  include DiscourseActivityPub::JsonLd
  include DiscourseActivityPub::DomainVerification
  include DiscourseActivityPub::SignatureVerification

  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token

  before_action :rate_limit
  before_action :ensure_site_enabled
  before_action :validate_headers
  before_action :ensure_domain_allowed
  before_action :ensure_verified_signature, if: :require_signed_requests?
  before_action :ensure_object_exists, if: :is_object_controller

  def show
    render json: @object.ap.json
  end

  protected

  def rate_limit
    limit = SiteSetting.activity_pub_rate_limit_get_objects_per_minute
    RateLimiter.new(nil, "activity-pub-object-get-min-#{request.remote_ip}", limit, 1.minute).performed!
  end

  rescue_from RateLimiter::LimitExceeded do
    render_json_error I18n.t("rate_limiter.slow_down"), status: 429
  end

  def ensure_site_enabled
    render_activity_pub_error("not_enabled", 403) unless Site.activity_pub_enabled
  end

  def validate_headers
    valid_content_header = case request.method
                           when "POST" then valid_content_type?(request.headers['Content-Type'])
                           when "GET" then valid_accept?(request.headers['Accept'])
                           end
    render_activity_pub_error("bad_request", 400) unless valid_content_header
  end

  def require_signed_requests?
    SiteSetting.activity_pub_require_signed_requests
  end

  def is_object_controller
    controller_name === "objects"
  end

  def ensure_object_exists
    render_activity_pub_error("not_found", 404) unless @object = DiscourseActivityPubObject.find_by(ap_key: params[:key])
  end

  def render_activity_pub_error(key, status, opts = {})
    render_json_error(I18n.t("discourse_activity_pub.request.error.#{key}", opts), status: status)
  end

  def render_ordered_collection(stored, collection_for)
    collection = DiscourseActivityPub::AP::Collection::OrderedCollection.new(stored: stored.send("#{collection_for}_collection"))
    render json: DiscourseActivityPub::AP::Collection::OrderedCollectionSerializer.new(collection, root: false).as_json
  end
end
