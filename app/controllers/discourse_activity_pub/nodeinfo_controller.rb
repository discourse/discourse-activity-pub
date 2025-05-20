# frozen_string_literal: true

module DiscourseActivityPub
  class NodeinfoController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

    before_action :ensure_site_enabled

    def index
      render json: Nodeinfo.index, content_type: "application/jrd+json"
    end

    def show
      nodeinfo = Nodeinfo.new(params[:version])
      raise Discourse::NotFound unless nodeinfo.supported_version?
      render_serialized(nodeinfo, NodeinfoSerializer, root: false)
    end
  end
end
