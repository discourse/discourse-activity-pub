# frozen_string_literal: true

module DiscourseActivityPub
  module Admin
    class AdminController < ::Admin::AdminController
      requires_plugin DiscourseActivityPub::PLUGIN_NAME

      include DiscourseActivityPub::EnabledVerification

      before_action :ensure_site_enabled

      def index
        head 202
      end
    end
  end
end
