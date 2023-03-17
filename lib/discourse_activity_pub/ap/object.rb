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
        stored&.uid
      end

      def type
        stored&.ap_type
      end

      def self.type
        self.new.type
      end

      def json
        return @json if @json.present?

        if stored && klass = AP::Object.get_klass(type)
          serializer = "#{klass}Serializer".classify.constantize
          @json = serializer.new(klass.new(stored: stored), root: false).as_json
          @json
        else
          {}
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
        self.descendants.find { |klass| klass.to_s.demodulize === type }
      end
    end
  end
end