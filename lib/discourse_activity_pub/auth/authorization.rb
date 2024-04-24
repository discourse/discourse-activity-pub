# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class Authorization
      include ActiveModel::SerializerSupport
      include JsonLd
      include HasErrors

      attr_reader :actor_id, :domain, :access_token

      def initialize(opts = {})
        return unless opts.present? && opts.is_a?(Hash)
        opts.with_indifferent_access

        @actor_id = opts[:actor_id]
        @domain = opts[:domain]
        @access_token = opts[:access_token]
      end

      def verify
        raise NotImplementedError
      end

      def save_app(data)
        PluginStore.set(plugin_store_key, domain, data)
      end

      def get_app
        data = PluginStore.get(plugin_store_key, domain)
        data ? App.new(domain, data) : nil
      end

      def self.create_app(domain)
        new(domain: domain).create_app
      end

      def self.get_app(domain)
        new(domain: domain).get_app
      end

      def self.save_app(domain, data)
        new(domain: domain).save_app(data)
      end

      def self.get_authorize_url(domain)
        new(domain: domain).get_authorize_url
      end

      def self.get_token(domain, params)
        new(domain: domain).get_token(params)
      end

      def self.get_actor_id(domain, access_token)
        new(domain: domain).get_actor_id(access_token)
      end

      def self.plugin_store_key
        new.plugin_store_key
      end

      def plugin_store_key
        "#{DiscourseActivityPub::PLUGIN_NAME}-#{platform_store_key}-app"
      end

      protected

      def request(path, verb: :post, body: nil, headers: nil, params: nil)
        uri = DiscourseActivityPub::URI.parse("https://#{domain}/#{path}")
        uri.query = ::URI.encode_www_form(params) if params

        opts = {}
        opts[:body] = body.to_json if body
        opts[:headers] = {}
        opts[:headers]["Content-Type"] = "application/json" if body
        headers.each { |k, v| opts[:headers][k] = v } if headers

        begin
          response = Excon.send(verb, uri.to_s, opts)
        rescue Excon::Error => e
          add_error(e.message)
        end

        if response&.body && raw = parse_json_ld(response.body)
          body_hash = raw.with_indifferent_access if raw.is_a?(Hash)
        end

        if ![200, 201, 202].include?(response&.status)
          if body_hash
            errors = [
              body_hash[:error],
              body_hash[:error_description],
              body_hash[:errors],
            ].flatten.compact
            errors.each { |error| add_error(error) }
          end
          return false
        end

        body_hash || true
      end
    end
  end
end
