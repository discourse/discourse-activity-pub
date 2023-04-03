# frozen_string_literal: true
module DiscourseActivityPubSiteExtension
  def activity_pub_enabled
    !SiteSetting.login_required && SiteSetting.activity_pub_enabled
  end
end