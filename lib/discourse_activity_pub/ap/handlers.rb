# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    module Handlers
      class ValidateError < StandardError; end
      class PerformError < StandardError; end
      class StoreError < StandardError; end

      def self.included(base)
        base.extend ClassMethods
      end

      def apply_handlers(object_type, handler_type, extra_args = {})
        Object.handlers(object_type.to_sym, handler_type).all? do |proc|
          begin
            proc.call(self, extra_args)
            true
          rescue ValidateError => error
            add_error(error)
            false
          end
        end
      end

      module ClassMethods
        def sorted_handlers
          @@sorted_handlers ||= clear_handlers!
        end
  
        def clear_handlers!
          @@sorted_handlers = {}
        end
  
        def handler_types
          %w(target validate perform store respond_to)
        end
  
        def handler_keys(object_type, handler_type)
          return nil unless handler_types.include?(handler_type.to_s)
          klass = get_klass(object_type.to_s)
          [klass.type.downcase.to_sym, handler_type.to_sym]
        end
  
        def handlers(object_type, handler_type)
          type, handler = handler_keys(object_type, handler_type)
          return [] unless type && handler
          klass = get_klass(object_type.to_s)
          base_type = klass.base_type.downcase.to_sym
          [*([*sorted_handlers.dig(*[type, handler])] + [*sorted_handlers.dig(*[base_type, handler])])]
            .map { |h| h[:proc] }
            .compact
        end
  
        def add_handler(object_type, handler_type, priority = 0, &block)
          type, handler = handler_keys(object_type, handler_type)
          return nil unless type && handler
          sorted_handlers[type] ||= {}
          sorted_handlers[type][handler] ||= []
          sorted_handlers[type][handler] << { priority: priority, proc: block }
          @@sorted_handlers[type][handler].sort_by! { |h| -h[:priority] }
        end
      end
    end
  end
end