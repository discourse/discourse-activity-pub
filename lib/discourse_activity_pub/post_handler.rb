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
      # We only create posts from objects in reply to other objects
      return nil unless user && object.stored&.in_reply_to_post

      reply_to = object.stored&.in_reply_to_post
      post = nil

      ActiveRecord::Base.transaction do
        begin
          post = PostCreator.create!(
            user,
            raw: object.content,
            topic_id: reply_to.topic.id,
            reply_to_post_number: reply_to.post_number
          )
        rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          log_failure("create", e.message)
          raise ActiveRecord::Rollback
        end

        object.stored.update(model_type: 'Post', model_id: post.id)
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