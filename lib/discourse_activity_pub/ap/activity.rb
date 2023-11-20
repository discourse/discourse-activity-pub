# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity < Object

      def base_type
        'Activity'
      end

      def actor
        stored ?
          AP::Actor.new(stored: stored.actor) :
          @actor
      end

      def object
        stored ?
          AP::Object.get_klass(stored.object.ap_type).new(stored: stored.object) :
          @object
      end

      def targets
        @targets ||= []
      end

      def process
        return false unless process_actor_and_object
        return false unless process_activity_targets
        return false unless perform_validate_activity

        ActiveRecord::Base.transaction do
          perform_activity
          store_activity
          respond_to_activity
        end
      end

      def process_activity_targets
        return true if target_activity
        process_failed("activity_not_targeted")
        false
      end

      def perform_validate_activity
        return true if validate_activity
        process_failed("activity_not_valid")
        false
      end

      def target_activity
        apply_handlers(type, :target)
      end

      def validate_activity
        apply_handlers(type, :validate)
      end

      def perform_activity
        apply_handlers(type, :perform)
      end

      def store_activity
        apply_handlers(type, :store)
      end

      def respond_to_activity
        apply_handlers(type, :respond_to)
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

      def follow?
        type == Follow.type
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
        return process_failed("cant_create_actor") unless actor.present?

        @object = Object.resolve_and_store(json[:object], self)
        return process_failed("cant_find_object") unless object.present?
        return process_failed("object_not_ready") unless object.stored&.ready?(type)
        return process_failed("activity_not_supported") unless actor.stored.can_perform_activity?(type, object.type)

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
