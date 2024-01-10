# frozen_string_literal: true

module DiscourseActivityPub
  PLUGIN_NAME ||= "discourse-activity-pub"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseActivityPub
  end

  def self.host
    if Rails.env.development? && ENV["RAILS_DEVELOPMENT_HOSTS"].present?
      ENV["RAILS_DEVELOPMENT_HOSTS"].split(",").first
    else
      Discourse.current_hostname
    end
  end

  def self.base_url
    "https://#{host}#{Discourse.base_path}"
  end

  def self.users_shared_inbox
    "#{base_url}#{users_shared_inbox_path}"
  end

  def self.users_shared_inbox_path
    "/ap/users/inbox"
  end

  def self.enabled
    SiteSetting.activity_pub_enabled
  end

  def self.publishing_enabled
    enabled && !SiteSetting.login_required
  end

  def self.icon_url
    SiteIconManager.large_icon_url
  end
end
