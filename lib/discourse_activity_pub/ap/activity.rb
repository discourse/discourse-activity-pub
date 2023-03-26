# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity < Object
      def base_type
        'Activity'
      end

      def actor
        return nil unless stored
        AP::Actor.new(stored: stored.actor)
      end

      def object
        return nil unless stored
        AP::Object.get_klass(stored.object.ap_type).new(stored: stored.object)
      end

      def process
        return false unless process_json

        raise NotImplementedError
      end

      def deliver
        raise NotImplementedError
      end

      def response?
        type && Response.types.include?(type)
      end

      def composed?
        type && Compose.types.include?(type)
      end

      def self.types
        activity = self.new
        raise NotImplementedError unless activity.respond_to?(:types)
        activity.types
      end

      protected

      def process_json
        resolved_actor = resolve_object(json[:actor])
        return process_failed("cant_resolve_actor") unless resolved_actor.present?

        ap_actor = AP::Actor.factory(resolved_actor)
        return process_failed("actor_not_supported") unless ap_actor.can_belong_to.include?(:external)

        actor = ap_actor.update_stored_from_json
        return process_failed("cant_create_actor") unless actor.present?

        model = Model.find_by_url(json['object'])
        return process_failed("object_not_valid") unless model.present?

        return process_failed("activity_not_available") unless Model.ready?(model)
        return process_failed("activity_not_supported") unless actor.can_perform_activity?(type, model.activity_pub_actor.ap_type)

        [actor, model]
      end

      def process_failed(warning_key)
        action = I18n.t("discourse_activity_pub.activity.warning.failed_to_process", object_id: json['id'])
        message = I18n.t("discourse_activity_pub.activity.warning.#{warning_key}")
        log_warning(action, message)
        false
      end

      def log_warning(action, message)
        Rails.logger.warn("[Discourse Activity Pub] #{action}: #{message}")
      end

      def enqueue_delivery(url, payload)
        # TODO: add delay to delivery
        Jobs.enqueue(:discourse_activity_pub_deliver, url: url, payload: payload)
      end
    end
  end
end
