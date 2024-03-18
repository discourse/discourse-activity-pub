# frozen_string_literal: true

module DiscourseActivityPub
  class WebfingerController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerfication

    skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

    before_action :ensure_site_enabled
    before_action :find_resource, only: [:index]

    def index
      # TODO: is this Cache Control correct for webfinger?
      expires_in 1.minutes
      render json: serialized_resource, content_type: Webfinger::CONTENT_TYPE
    end

    protected

    def serialized_resource
      DiscourseActivityPub::WebfingerSerializer.new(@resource, root: false).as_json
    end

    def find_resource
      scheme, uri = params.require(:resource).split(":", 2)
      unless Webfinger::SUPPORTED_SCHEMES.include?(scheme)
        return render_webfinger_error("resource_not_supported", 405)
      end

      @resource = Webfinger.new(scheme).find(uri)
      render_webfinger_error("resource_not_found", 400) unless @resource.present?
    end

    def render_webfinger_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.webfinger.error.#{key}"), status: status
    end
  end
end
