# frozen_string_literal: true
module DiscourseActivityPub
  class PostHandler
    attr_reader :user,
                :object

    def initialize(user, object)
      @user = user
      @object = object
    end

    def create
      # We only create posts from objects with a model in reply to other objects
      return nil unless user && !object.model_id && object.in_reply_to_post

      reply_to = object.in_reply_to_post
      post = nil

      ActiveRecord::Base.transaction do
        begin
          params = {
            raw: object.content,
            topic_id: reply_to.topic.id,
            reply_to_post_number: reply_to.post_number,
            skip_events: true,
            skip_validations: true,
            custom_fields: {}
          }
          if object.published_at
            params[:custom_fields][:activity_pub_published_at] = object.published_at&.to_datetime.utc.iso8601
          end
          post = PostCreator.create!(user, params)
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

    def self.create(user, object)
      new(user, object).create
    end
  end
end