# frozen_string_literal: true

module DiscourseActivityPub
  class Logger
    include JsonLd

    PREFIX = "[Discourse Activity Pub]"
    attr_reader :type
    cattr_accessor :to_stdout

    def initialize(type)
      @type = type
    end

    def log(message, json: nil)
      return if self.class.log_types.exclude?(type)

      puts formatted_message(message) if print_to_stdout?

      DiscourseActivityPubLog.create(level: type, message: message, json: json)

      return unless SiteSetting.activity_pub_verbose_logging
      rails_args = {}
      rails_args[:json] = json if SiteSetting.activity_pub_object_logging && !Rails.env.development?

      Rails.logger.send(type, formatted_message(message, **rails_args))
      AP.logger.send(type, formatted_message(message, json: json)) if Rails.env.development?

      true
    end

    def formatted_message(message, json: nil)
      result = "#{PREFIX} #{message}"
      if json.present?
        json = parse_json_ld(json) if json.is_a?(String)
        result += "\n#{json.to_yaml}" if json.present?
      end
      result
    end

    def print_to_stdout?
      case to_stdout
      when :error
        type == :error
      when :info
        %i[error info].include?(type)
      when :warn
        %i[error info warn].include?(type)
      else
        false
      end
    end

    def self.log_types
      %i[error warn info]
    end

    def self.error(message, json: nil)
      new(:error).log(message, json: json)
    end

    def self.warn(message, json: nil)
      new(:warn).log(message, json: json)
    end

    def self.info(message, json: nil)
      new(:info).log(message, json: json)
    end

    def self.object_store_error(object, error)
      error(error.record.errors.map { |e| e.full_message }.join(","), json: object.json)
    end
  end
end
