# frozen_string_literal: true
module DiscourseActivityPub
  module EnabledVerfication
    def ensure_site_enabled
      render_not_enabled unless DiscourseActivityPub.enabled
    end

    def ensure_publishing_enabled
      render_not_enabled unless DiscourseActivityPub.publishing_enabled
    end

    def render_not_enabled
      render_json_error I18n.t("discourse_activity_pub.not_enabled"), status: 403
    end
  end
end