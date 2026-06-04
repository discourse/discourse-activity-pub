# frozen_string_literal: true

require "net/http"
require "uri"

module DiscourseActivityPub
  class DebugFetchController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr

    def show
      uri = URI.parse(params.require(:url))
      response = Net::HTTP.get_response(uri)

      render plain: response.body, status: response.code.to_i
    end
  end
end
