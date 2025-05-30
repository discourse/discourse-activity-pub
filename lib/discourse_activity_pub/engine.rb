# frozen_string_literal: true

module DiscourseActivityPub
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseActivityPub
    config.autoload_paths << File.join(config.root, "lib")
  end

  class AuthFailed < StandardError
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

  def self.info(ap_ids)
    return nil unless ap_ids

    results = DB.query(<<~SQL, ap_ids: ap_ids)
      SELECT id, 'Activity' as type, ap_type, COALESCE(local, FALSE) as local, replace(object_type, 'DiscourseActivityPub', '') as object_type, object_id, NULL as model_type, NULL as model_id
      FROM discourse_activity_pub_activities
      WHERE ap_id = ANY (ARRAY[:ap_ids])
      UNION
      SELECT id, 'Actor' as type, ap_type, COALESCE(local, FALSE) as local, NULL as object_type, NULL as object_id, model_type, model_id
      FROM discourse_activity_pub_actors
      WHERE ap_id = ANY (ARRAY[:ap_ids])
      UNION
      SELECT id, 'Collection' as type, ap_type, COALESCE(local, FALSE) as local, NULL as object_type, NULL as object_id, model_type, model_id
      FROM discourse_activity_pub_collections
      WHERE ap_id = ANY (ARRAY[:ap_ids])
      UNION
      SELECT id, 'Object' as type, ap_type, COALESCE(local, FALSE) as local, NULL as object_type, NULL as object_id, model_type, model_id
      FROM discourse_activity_pub_objects
      WHERE ap_id = ANY (ARRAY[:ap_ids])
    SQL

    return nil if results.blank?

    results.each do |result|
      if result.type == "Activity" && result.object_type == "Object"
        object = DiscourseActivityPubObject.find_by(id: result.object_id)
        result.model_type = object.model_type
        result.model_id = object.model_id
      end
    end

    results
  end
end
