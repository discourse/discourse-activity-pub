# frozen_string_literal: true
module DiscourseActivityPub
  class PostHandler
    attr_reader :user,
                :object

    def initialize(user, object)
      @user = user
      @object = object
    end

    def create(target: nil)
      return nil if !user || !object || object.model_id || (
        !object.in_reply_to_post && !can_create_topic?(target)
      )

      params = {
        raw: object.content,
        skip_events: true,
        skip_validations: true,
        custom_fields: {}
      }

      if object.in_reply_to_post
        reply_to = object.in_reply_to_post
        params[:topic_id] = reply_to.topic.id
        params[:reply_to_post_number] = reply_to.post_number
      else
        params[:title] = object.summary || DiscourseActivityPub::ContentParser.get_title(
          object.content
        )
        params[:category] = target.model.id
      end

      if object.published_at
        params[:custom_fields][:activity_pub_published_at] = object.published_at&.to_datetime.utc.iso8601
      end

      post = nil

      ActiveRecord::Base.transaction do
        begin
          post = PostCreator.create!(user, params)
          post.topic.create_activity_pub_collection! unless params[:topic_id]
        rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          log_failure("create", e.message)
          raise ActiveRecord::Rollback
        end

        if post
          object.update(
            model_type: 'Post',
            model_id: post.id,
            collection_id: post.topic.activity_pub_object.id
          )
        end
      end

      post
    end

    def log_failure(verb, message)
      return unless SiteSetting.activity_pub_verbose_logging

      prefix = "#{user.username} failed to #{verb} post for #{object.id}"
      Rails.logger.warn("[Discourse Activity Pub] #{prefix}: #{message}")
    end

    def self.create(user, object, target = nil)
      new(user, object).create(target: target)
    end

    protected

    def can_create_topic?(target)
      return false unless target&.model
      return false unless target.model.is_a?(Category)
      return false unless target.model.activity_pub_ready?

      target.model.activity_pub_full_topic
    end
  end
end