# frozen_string_literal: true

module DiscourseActivityPub
  class PostController < ApplicationController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_site_enabled
    before_action :ensure_staff
    before_action :find_post
    before_action :ensure_first_post

    def deliver
      if !@post.activity_pub_published? || @post.activity_pub_taxonomy_followers.empty?
        return render_post_error("cant_deliver_post", 422)
      end

      if @post.activity_pub_deliver!
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def publish
      if @post.activity_pub_published? || @post.activity_pub_scheduled?
        return render_post_error("cant_publish_post", 422)
      end

      @post.performing_activity_delivery_delay = 0

      if @post.activity_pub_publish!
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def schedule
      if @post.activity_pub_published? || @post.activity_pub_scheduled? ||
           @post.activity_pub_taxonomy_followers.blank?
        return render_post_error("cant_schedule_post", 422)
      end

      if @post.activity_pub_schedule!
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def unschedule
      if (@post.activity_pub_published? || !@post.activity_pub_scheduled?)
        return render_post_error("cant_unschedule_post", 422)
      end

      if @post.activity_pub_unschedule!
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    protected

    def ensure_first_post
      render_post_error("not_first_post", 422) unless @post.activity_pub_is_first_post?
    end

    def find_post
      @post = Post.find_by(id: params[:post_id])
      render_post_error("post_not_found", 400) if @post.blank?
    end

    def render_post_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.post.error.#{key}"), status: status
    end
  end
end
