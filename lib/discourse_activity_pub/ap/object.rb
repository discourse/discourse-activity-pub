# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    class Object
      include JsonLd
      include ActiveModel::SerializerSupport

      attr_writer :json

      def context
        DiscourseActivityPub::JsonLd::ACTIVITY_STREAMS_CONTEXT
      end

      def id
        json[:id]
      end

      def type
        json[:type]
      end

      def self.type
        self.new.type
      end

      def json
        @json.nil? ? {} : @json
      end

      def self.factory(json)
        json = json.with_indifferent_access
        klass = nil

        self.descendants.each do |k|
          if k.to_s.demodulize === json[:type]
            klass = k
          end
        end
        return nil unless klass

        instance = klass.new
        instance.json = json
        instance
      end
    end
  end
end