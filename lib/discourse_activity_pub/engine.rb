# frozen_string_literal: true

module DiscourseActivityPub
  PLUGIN_NAME ||= 'discourse-activity-pub'

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseActivityPub
  end

  def self.host
    if Rails.env.development? && ENV["RAILS_DEVELOPMENT_HOSTS"].present?
      ENV["RAILS_DEVELOPMENT_HOSTS"].split(',').first
    else
      Discourse.current_hostname
    end
  end

  def self.base_url
    "#{Discourse.base_protocol}://#{host}#{Discourse.base_path}"
  end
end