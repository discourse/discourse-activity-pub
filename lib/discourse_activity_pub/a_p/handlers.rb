# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    module Handlers
      class Warning < StandardError
        class Validate < Warning
        end
      end
      class Error < StandardError
        class Perform < Error
        end
        class Store < Error
        end
        class RespondTo < Error
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      def apply_handlers(object_type, handler_type, parent: nil, raise_errors: false)
        self.class.apply_handlers(
          self,
          object_type,
          handler_type,
          parent: parent,
          raise_errors: raise_errors,
        )
      end

      module ClassMethods
        def sorted_handlers
          @@sorted_handlers ||= clear_handlers!
        end

        def clear_handlers!
          @@sorted_handlers = {}
        end

        def handler_types
          %w[validate perform resolve store respond_to forward]
        end

        def handler_keys(object_type, handler_type)
          return nil if handler_types.exclude?(handler_type.to_s)
          klass = get_klass(object_type.to_s)
          [klass.type.downcase.to_sym, handler_type.to_sym]
        end

        def handlers(object_type, handler_type)
          type, handler = handler_keys(object_type, handler_type)
          return [] unless type && handler
          klass = get_klass(object_type.to_s)
          _handlers = [*sorted_handlers.dig(*[type, handler])]
          base_type = klass.base_type.downcase.to_sym
          _handlers += [*sorted_handlers.dig(*[base_type, handler])] if type != base_type
          _handlers.map { |h| h[:proc] }.compact
        end

        def add_handler(object_type, handler_type, priority = 0, &block)
          type, handler = handler_keys(object_type, handler_type)
          return nil unless type && handler
          sorted_handlers[type] ||= {}
          sorted_handlers[type][handler] ||= []
          sorted_handlers[type][handler] << { priority: priority, proc: block }
          @@sorted_handlers[type][handler].sort_by! { |h| -h[:priority] }
        end

        def apply_handlers(activity, object_type, handler_type, parent: nil, raise_errors: false)
          Object
            .handlers(object_type.to_sym, handler_type)
            .all? do |proc|
              begin
                proc.call(activity, { parent: parent })
                true
              rescue DiscourseActivityPub::AP::Handlers::Warning,
                     DiscourseActivityPub::AP::Handlers::Error => error
                activity.add_error(error)
                raise_errors ? raise : false
              end
            end
        end
      end
    end
  end
end
