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

  def self.info(ap_id)
    result = DB.query(<<~SQL, ap_id: ap_id)
      SELECT id, 'Activity' as type, ap_type, COALESCE(local, FALSE) as local
      FROM discourse_activity_pub_activities
      WHERE ap_id = :ap_id
      UNION
      SELECT id, 'Actor' as type, ap_type, COALESCE(local, FALSE) as local
      FROM discourse_activity_pub_actors
      WHERE ap_id = :ap_id
      UNION
      SELECT id, 'Collection' as type, ap_type, COALESCE(local, FALSE) as local
      FROM discourse_activity_pub_collections
      WHERE ap_id = :ap_id
      UNION
      SELECT id, 'Object' as type, ap_type, COALESCE(local, FALSE) as local
      FROM discourse_activity_pub_objects
      WHERE ap_id = :ap_id
    SQL
    result.present? ? result.first : nil
  end
end
