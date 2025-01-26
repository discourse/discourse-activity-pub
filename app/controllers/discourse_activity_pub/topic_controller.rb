# frozen_string_literal: true

module DiscourseActivityPub
  class TopicController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_site_enabled
    before_action :ensure_staff
    before_action :find_topic
    before_action :ensure_can_publish

    def publish
      @topic.activity_pub_publish!
      render json: success_json
    end

    protected

    def ensure_can_publish
      if !@topic.activity_pub_full_topic || @topic.activity_pub_published? ||
           @topic.activity_pub_first_post_scheduled?
        render_topic_error("cant_publish_topic", 422)
      end
    end

    def find_topic
      @topic = Topic.find_by(id: params[:topic_id])
      render_topic_error("topic_not_found", 400) if @topic.blank?
    end

    def render_topic_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.topic.error.#{key}"), status: status
    end
  end
end
