# frozen_string_literal: true

module DiscourseActivityPub
  class OAuth
    class App
      attr_reader :domain,
                  :client_id,
                  :client_secret

      def initialize(domain, data)
        data.with_indifferent_access

        @domain = domain
        @client_id = data[:client_id]
        @client_secret = data[:client_secret]
      end
    end
  end
end