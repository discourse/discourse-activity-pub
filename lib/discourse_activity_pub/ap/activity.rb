# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity < Object
      class ValidationError < StandardError; end
      class PerformanceError < StandardError; end

      HANDLER_TYPES = %w(validate perform)

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
        return false unless perform_validate_activity

        ActiveRecord::Base.transaction do
          perform_activity
          store_activity
          respond_to_activity
        end
      end

      def perform_validate_activity
        return true if validate_activity
        process_failed("activity_not_valid")
        false
      end

      def validate_activity
        Activity.handlers(type.to_sym, :validate).all? do |proc|
          begin
            proc.call(actor, object)
            true
          rescue ValidationError => error
            add_error(error)
            false
          end
        end
      end

      def perform_activity
        Activity.handlers(type.to_sym, :perform).all? do |proc|
          begin
            proc.call(actor, object)
            true
          rescue PerformanceError => error
            add_error(error)
            false
          end
        end
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

      def create?
        type == Create.type
      end

      def delete?
        type == Delete.type
      end

      def update?
        type == Update.type
      end

      def self.types
        activity = self.new
        raise NotImplementedError unless activity.respond_to?(:types)
        activity.types
      end

      def self.sorted_handlers
        @@sorted_handlers ||= clear_handlers!
      end

      def self.clear_handlers!
        @@sorted_handlers = {}
      end

      def self.handler_keys(activity_type, handler_type)
        return nil unless HANDLER_TYPES.include?(handler_type.to_s)
        klass = get_klass(activity_type.to_s)
        [klass.type.downcase.to_sym, handler_type.to_sym]
      end

      def self.handlers(activity_type, handler_type)
        type, handler = handler_keys(activity_type, handler_type)
        return [] unless type && handler
        (sorted_handlers.dig(*[type, handler]) || []).map { |h| h[:proc] }
      end

      def self.add_handler(activity_type, handler_type, priority = 0, &block)
        type, handler = handler_keys(activity_type, handler_type)
        return nil unless type && handler
        sorted_handlers[type] ||= {}
        sorted_handlers[type][handler] ||= []
        sorted_handlers[type][handler] << { priority: priority, proc: block }
        @@sorted_handlers[type][handler].sort_by! { |h| -h[:priority] }
      end

      protected

      def process_actor_and_object
        @actor = AP::Actor.resolve_and_store(json[:actor])
        return process_failed("cant_create_actor") unless actor.present?

        @object = AP::Object.resolve_and_store(json[:object], self)
        return process_failed("cant_find_object") unless object.present?
        return process_failed("object_not_ready") unless object.stored.ready?
        return process_failed("activity_not_supported") unless actor.stored.can_perform_activity?(type, object.type)

        true
      end
    end
  end
end
