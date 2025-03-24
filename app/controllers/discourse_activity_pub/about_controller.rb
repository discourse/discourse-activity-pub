# frozen_string_literal: true

module DiscourseActivityPub
  class AboutController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_site_enabled

    def index
      render_serialized(About.new, AboutSerializer, root: false)
    end
  end
end
