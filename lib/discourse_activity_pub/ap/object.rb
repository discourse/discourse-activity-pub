# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      include JsonLd
      include ActiveModel::SerializerSupport

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
        stored&.ap_type
      end

      def base_type
        'Object'
      end

      def url
        stored&.respond_to?(:url) && stored.url
      end

      def to
        stored&.respond_to?(:to) && stored.to
      end

      def self.type
        self.new.type
      end

      def self.base_type
        self.new.base_type
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
        message = I18n.t("discourse_activity_pub.process.warning.#{warning_key}")
        log_warning(action, message)
        false
      end

      def self.process_failed(object_id, warning_key)
        self.new(json: { id: object_id }).process_failed(warning_key)
      end

      def log_warning(action, message)
        if SiteSetting.activity_pub_verbose_logging
          Rails.logger.warn("[Discourse Activity Pub] #{action}: #{message}")
        end
      end

      def self.factory(json)
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
        self.descendants.find do |klass|
          klass.to_s.demodulize.downcase === type.downcase
        end
      end

      def self.find_local(raw_object, activity_type)
        object_id = DiscourseActivityPub::JsonLd.resolve_id(raw_object)
        stored = case activity_type
          when AP::Activity::Follow.type
            DiscourseActivityPubActor.find_by(ap_id: object_id)
          when AP::Activity::Undo.type
            DiscourseActivityPubActivity.find_by(ap_id: object_id)
          else
            nil
          end
        stored&.ap
      end
    end
  end
end