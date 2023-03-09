# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity < Object

      attr_accessor :activity

      def initialize(activity: nil)
        @activity = activity
      end

      def id
        activity&.uid || super
      end

      def actor
        activity&.actor&.uid
      end

      def object
        activity&.object&.uid
      end

      def process
        return false unless process_json

        raise NotImplementedError
      end

      protected

      def process_json
        resolved_actor = resolve_object(json[:actor])
        return process_failed("cant_resolve_actor") unless resolved_actor.present?

        ap_actor = AP::Actor.factory(resolved_actor)
        return process_failed("actor_not_supported") unless ap_actor.can_belong_to.include?(:external)

        actor = ap_actor.create_or_update_from_json
        return process_failed("cant_create_actor") unless actor.present?

        model = Model.find_by_url(json['object'])
        return process_failed("object_not_valid") unless model.present?

        return process_failed("activity_not_enabled") unless Model.enabled?(model)
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

      def deliver_ap_response(to_url, ap_response)
        payload = AP::Activity::ResponseSerializer.new(ap_response, root: false).as_json
        Jobs.enqueue(:discourse_activity_pub_deliver, url: to_url, payload: payload)
      end
    end
  end
end
