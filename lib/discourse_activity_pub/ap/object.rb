# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      include JsonLd
      include ActiveModel::SerializerSupport
      include HasErrors
      include Handlers

      attr_writer :json
      attr_accessor :stored

      def initialize(json: nil, stored: nil)
        @json = json
        @stored = stored
      end

      def context
        DiscourseActivityPub::JsonLd::ACTIVITY_STREAMS_CONTEXT
      end

      def id
        stored&.ap_id
      end

      def type
        stored&.ap_type || base_type
      end

      def base_type
        'Object'
      end

      def object?
        base_type == "Object"
      end

      def activity?
        base_type == "Activity"
      end

      def collection?
        base_type == "Collection"
      end

      def url
        stored&.respond_to?(:url) && stored.url
      end

      def to
        stored&.respond_to?(:to) && stored.to
      end

      def start_time
        stored&.respond_to?(:created_at) && stored.created_at.iso8601
      end

      def updated
        stored&.respond_to?(:updated_at) && stored.updated_at.iso8601
      end

      def published
        stored&.respond_to?(:published_at) && stored.published_at&.iso8601
      end

      def json
        return @json if @json.present?

        if stored && klass = AP::Object.get_klass(type)
          serializer = "#{klass}Serializer".classify.constantize
          @json = serializer.new(klass.new(stored: stored), root: false)
            .as_json
            .with_indifferent_access
          @json
        else
          {}
        end
      end

      def process_failed(warning_key)
        action = I18n.t("discourse_activity_pub.process.warning.failed_to_process", object_id: json[:id])
        if errors.any?
          message = errors.map { |e| e.full_message }.join(",")
        else
          message = I18n.t("discourse_activity_pub.process.warning.#{warning_key}")
        end
        log_warning(action, message)
        false
      end

      def log_warning(action, message)
        if SiteSetting.activity_pub_verbose_logging
          Rails.logger.warn("[Discourse Activity Pub] #{action}: #{message}")
        end
      end

      def self.type
        self.new.type
      end

      def self.base_type
        self.new.base_type
      end

      def self.process_failed(object_id, warning_key)
        self.new(json: { id: object_id }).process_failed(warning_key)
      end

      def self.factory(json)
        return nil unless json&.is_a?(Hash)

        json = json.with_indifferent_access
        klass = AP::Object.get_klass(json[:type])
        return nil unless klass

        object = klass.new
        object.json = json
        object
      end

      def self.from_type(type)
        factory({ type: type.to_s.capitalize })
      end

      def self.get_klass(type)
        ([self] + self.descendants).find do |klass|
          klass.to_s.demodulize.downcase === type.downcase
        end
      end

      def self.resolve_and_store(raw_object, activity = nil)
        resolved_object = DiscourseActivityPub::JsonLd.resolve_object(raw_object)
        return process_failed(raw_object, "cant_resolve_object") unless resolved_object.present?

        object = factory(resolved_object)
        return process_failed(resolved_object['id'], "cant_resolve_object") unless object.present?

        if object.respond_to?(:can_belong_to) && !object.can_belong_to.include?(:remote)
          return process_failed(resolved_object['id'], "object_not_supported")
        end

        object.apply_handlers(type, :store, { activity: activity })

        object
      end
    end
  end
end