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

      def start_time
        stored&.created_at
      end

      def process
        return false unless process_actor_and_object
        return false unless validate_activity

        ActiveRecord::Base.transaction do
          perform_activity
          store_activity
          respond_to_activity
        end
      end

      def validate_activity
        true
      end

      def perform_activity
      end

      def store_activity
        @stored = DiscourseActivityPubActivity.create!(
          ap_id: json[:id],
          ap_type: type,
          actor_id: actor.stored.id,
          object_id: object.stored.id,
          object_type: object.stored.class.name
        )
      end

      def respond_to_activity
      end

      def response?
        type && Response.types.include?(type)
      end

      def composition?
        type && Compose.types.include?(type)
      end

      def self.types
        activity = self.new
        raise NotImplementedError unless activity.respond_to?(:types)
        activity.types
      end

      protected

      def process_actor_and_object
        @actor = AP::Actor.resolve_and_store(json[:actor])
        return process_failed("cant_create_actor") unless actor.present?

        @object = AP::Object.find_local(json[:object], type)
        return process_failed("cant_find_object") unless object.present?
        return process_failed("object_not_ready") unless object.stored.ready?
        return process_failed("activity_not_supported") unless actor.stored.can_perform_activity?(type, object.type)

        true
      end
    end
  end
end
