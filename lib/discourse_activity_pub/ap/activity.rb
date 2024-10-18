# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity < Object
      attr_writer :actor, :object

      def base_type
        "Activity"
      end

      def actor
        stored ? AP::Actor.new(stored: stored.actor) : @actor
      end

      def object
        if stored&.object
          klass = AP::Object.get_klass(stored.object.ap_type)
          klass.new(stored: stored.object, parent: self)
        else
          @object
        end
      end

      def process
        return false unless perform_transactions
        forward_activity
        self
      end

      def perform_transactions(skip_process: false)
        performed = true

        ActiveRecord::Base.transaction do
          begin
            process_activity unless skip_process
            validate_activity
            perform_activity
            store_activity
            respond_to_activity
          rescue DiscourseActivityPub::AP::Handlers::Warning => warning
            DiscourseActivityPub::Logger.warn(warning.message) if warning.message
            performed = false
            raise ActiveRecord::Rollback
          rescue DiscourseActivityPub::AP::Handlers::Error => error
            DiscourseActivityPub::Logger.error(error.message) if error.message
            performed = false
            raise ActiveRecord::Rollback
          end
        end

        performed
      end

      def process_activity
        raise DiscourseActivityPub::AP::Handlers::Warning unless process_actor_and_object
      end

      def validate_activity
        apply_handlers(type, :validate, raise_errors: true)
      end

      def perform_activity
        apply_handlers(type, :perform, raise_errors: true)
      end

      def store_activity
        apply_handlers(type, :store, raise_errors: true)
      end

      def respond_to_activity
        apply_handlers(type, :respond_to, raise_errors: true)
      end

      def forward_activity
        apply_handlers(type, :forward)
      end

      def response?
        type && Response.types.include?(type)
      end

      def composition?
        type && Compose.types.include?(type)
      end

      def create?
        type == Create.type
      end

      def delete?
        type == Delete.type
      end

      def update?
        type == Update.type
      end

      def like?
        type == Like.type
      end

      def undo?
        type == Undo.type
      end

      def undo_like?
        undo? && object&.like?
      end

      def follow?
        type == Follow.type
      end

      def reject?
        type == Reject.type
      end

      def announce?
        type == Announce.type
      end

      def self.types
        activity = self.new
        raise NotImplementedError unless activity.respond_to?(:types)
        activity.types
      end

      protected

      def process_actor_and_object
        @actor = Actor.resolve_and_store(json[:actor])
        return process_failed("cant_create_actor") if actor.blank?

        @object = Object.resolve_and_store(json[:object], self)
        return process_failed("cant_find_object") if object.blank?
        return process_failed("object_not_ready") unless object.stored&.ready?(type)
        unless actor.stored.can_perform_activity?(type, object.type)
          return process_failed("activity_not_supported")
        end

        true
      end

      def activity_host_matches_object_host?
        return true if DiscourseActivityPub::URI.matching_hosts?(json[:id], object.id)
        process_failed("activity_host_must_match_object_host")
        false
      end
    end
  end
end
