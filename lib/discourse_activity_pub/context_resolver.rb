# frozen_string_literal: true

module DiscourseActivityPub
  class ContextResolver
    include HasErrors

    REPLY_DEPTH_LIMIT = 3

    attr_reader :object
    attr_accessor :local_object, :remote_objects

    def initialize(object)
      @object = object
    end

    def perform
      return unless resolve_context?

      traverse_replies

      if local_object
        resolve_and_store_remote_objects
      else
        add_error(I18n.t("discourse_activity_pub.process.warning.cannot_resolve_context"))
      end
    end

    def success?
      errors.blank?
    end

    def self.perform(object)
      new(object).perform
    end

    protected

    def resolve_context?
      # Resolve the context of unhandled replies without a post in reply to
      object.model_id.blank? && object.reply_to_id.present? && object.in_reply_to_post.blank?
    end

    def traverse_replies
      reply_depth = 1
      reply_to_object = object.ap
      @local_object = nil
      @remote_objects = []

      while local_object.nil? && reply_to_object&.in_reply_to.present? &&
              reply_depth <= REPLY_DEPTH_LIMIT
        reply_to_object =
          DiscourseActivityPub::AP::Object.resolve(
            reply_to_object.in_reply_to,
            resolve_attribution: false,
          )
        break unless reply_to_object.present?

        object = DiscourseActivityPubObject.find_by(ap_id: reply_to_object.id)
        if object
          # We only resolve a context in a full_topic topic
          if object.model&.topic&.activity_pub_full_topic_enabled
            @local_object = object
          else
            reply_to_object = nil
          end
        else
          remote_objects << reply_to_object
        end

        reply_depth += 1
      end
    end

    def resolve_and_store_remote_objects
      # If anything fails everything has to be rolled back
      ActiveRecord::Base.transaction do
        remote_objects.each do |remote_object|
          new_local_object =
            DiscourseActivityPub::AP::Object.resolve_and_store(
              remote_object.json,
              DiscourseActivityPub::AP::Activity.factory(
                { type: DiscourseActivityPub::AP::Activity::Create.type },
              ),
            )
          rollback_remote_store unless new_local_object&.stored.present?

          user =
            DiscourseActivityPub::ActorHandler.update_or_create_user(
              new_local_object.stored.attributed_to,
            )
          rollback_remote_store unless user.present?

          post =
            DiscourseActivityPub::PostHandler.create(
              user,
              new_local_object.stored,
              topic_id: local_object.model.topic_id,
            )
          rollback_remote_store unless post.present?
        end
      end
    end

    def rollback_remote_store
      add_error(I18n.t("discourse_activity_pub.process.warning.cannot_resolve_context"))
      raise ActiveRecord::Rollback
    end
  end
end
