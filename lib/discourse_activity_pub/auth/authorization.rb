# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class Authorization
      include ActiveModel::SerializerSupport

      attr_reader :domain,
                  :access

      def initialize(data = {})
        data.with_indifferent_access

        @domain = data[:domain]
        @access = !!data[:access_token]
      end
    end
  end
end