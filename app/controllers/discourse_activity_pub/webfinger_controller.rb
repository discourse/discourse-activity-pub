# frozen_string_literal: true

class DiscourseActivityPub::WebfingerController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

  before_action :ensure_site_enabled
  before_action :find_resource

  def index
    expires_in 1.minutes
    render json: serialized_resource, content_type: Webfinger::CONTENT_TYPE
  end

  protected

  def serialized_resource
    DiscourseActivityPub::WebfingerSerializer.new(@resource, root: false).as_json
  end

  def find_resource
    scheme, uri = params.require(:resource).split(':', 2)
    render_webfinger_error("resource_not_supported", 405) unless Webfinger::SUPPORTED_SCHEMES.include?(scheme)

    @resource = Webfinger.new(scheme).find(uri)
    render_webfinger_error("resource_not_found", 400) unless @resource.present?
  end

  def ensure_site_enabled
    render_webfinger_error("not_enabled", 403) unless SiteSetting.activity_pub_enabled && !SiteSetting.login_required
  end

  def render_webfinger_error(key, status)
    render_json_error I18n.t("discourse_activity_pub.webfinger.error.#{key}"), status: status
  end
end