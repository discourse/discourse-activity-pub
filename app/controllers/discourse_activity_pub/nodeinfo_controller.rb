# frozen_string_literal: true

module DiscourseActivityPub
  class NodeinfoController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

    before_action :ensure_site_enabled

    def index
      render json: Nodeinfo.index, content_type: Nodeinfo::CONTENT_TYPE
    end
  end
end
