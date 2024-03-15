# frozen_string_literal: true

module DiscourseActivityPub
  module Admin
    class AdminController < ::Admin::AdminController
      before_action :ensure_site_enabled

      def index
        head 202
      end

      protected

      def ensure_site_enabled
        raise Discourse::NotFound.new unless DiscourseActivityPub.enabled
      end
    end
  end
end
