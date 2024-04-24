# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class App
      attr_reader :domain, :client_id, :client_secret, :pem
      attr_accessor :nonce

      def initialize(domain, data)
        return unless data.present? && data.is_a?(Hash)
        data.with_indifferent_access

        @domain = domain
        @client_id = data[:client_id]
        @client_secret = data[:client_secret]
        @pem = data[:pem]
        @nonce = data[:nonce]
      end
    end
  end
end
