# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      include JsonLd
      include ActiveModel::SerializerSupport
      include HasErrors
      include Handlers

      attr_writer :json
      attr_writer :attributed_to
      attr_accessor :stored
      attr_accessor :delivered_to
      attr_accessor :cache
      attr_accessor :parent

      def initialize(json: nil, stored: nil, parent: nil)
        @json = json
        @stored = stored
        @parent = parent
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

      def actor?
        base_type == "Actor"
      end

      def url
        stored&.respond_to?(:url) && stored.url
      end

      def audience
        stored&.respond_to?(:audience) && stored.audience
      end

      def to
        return nil unless stored
        return stored.to if stored.respond_to?(:to)

        # See https://www.w3.org/TR/activitypub/#create-activity-outbox
        return parent.stored.to if parent&.create? && parent&.stored&.respond_to?(:to)
      end

      def cc
        return nil unless stored
        return stored.cc if stored.respond_to?(:cc)

        # See https://www.w3.org/TR/activitypub/#create-activity-outbox
        return parent.stored.cc if parent&.create? && parent&.stored&.respond_to?(:cc)
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

      def attributed_to
        stored ?
          stored.respond_to?(:attributed_to) && stored.attributed_to&.ap :
          @attributed_to
      end

      def summary
        stored&.respond_to?(:summary) && stored.summary
      end

      def name
        stored&.respond_to?(:name) && stored.name
      end

      def context
        stored&.respond_to?(:context) && stored.context
      end

      def target
        stored&.respond_to?(:target) && stored.target
      end

      def delivered_to
        @delivered_to ||= []
      end

      def cache
        @cache ||= {}
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
          object = klass.new(stored: stored)
          object.parent = parent if parent.present?
          @json = serializer.new(object, root: false)
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
        DiscourseActivityPub::Logger.warn("#{action}: #{message}")
        false
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

      def self.resolve_and_store(raw_object, parent = nil)
        object = resolve(raw_object)
        return unless object
        object.apply_handlers(type, :resolve, parent: parent)
        object.apply_handlers(type, :store, parent: parent)
        object
      end

      def self.resolve(raw_object)
        object_id = DiscourseActivityPub::JsonLd.resolve_id(raw_object)
        return process_failed(raw_object, "cant_resolve_object") unless object_id.present?

        if DiscourseActivityPub::URI.local?(object_id)
          object = if raw_object.is_a?(Hash)
            factory(raw_object)
          else
            factory({ type: Object.type, id: object_id })
          end
          return object
        end

        resolved_object = DiscourseActivityPub::JsonLd.resolve_object(raw_object)
        return process_failed(raw_object, "cant_resolve_object") unless resolved_object.present?

        object = factory(resolved_object)
        return process_failed(resolved_object['id'], "cant_resolve_object") unless object.present?

        if object.respond_to?(:can_belong_to) && !object.can_belong_to.include?(:remote)
          return process_failed(resolved_object['id'], "object_not_supported")
        end

        if object.json[:attributedTo]
          attributed_to = Actor.resolve_and_store(object.json[:attributedTo])
          object.attributed_to = attributed_to if attributed_to.present?
        end

        object
      end
    end
  end
end