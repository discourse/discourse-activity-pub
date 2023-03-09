# frozen_string_literal: true

module DiscourseActivityPub
  PLUGIN_NAME ||= 'discourse-activity-pub'

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseActivityPub
  end
end