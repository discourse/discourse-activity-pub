# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Response < Activity
        include HasErrors

        def type
          return stored.ap_type if stored.present?
          rejected? ? Reject.type : Accept.type
        end

        def types
          [Accept.type, Reject.type]
        end

        def summary
          return stored.summary if stored.present?
          rejected? ? errors.full_messages.first : nil
        end

        def rejected?
          errors.any?
        end

        def accepted?
          errors.blank?
        end

        def reject(key: nil, message: nil)
          add_error(key ? reject_message_from_key(key) : message)
        end

        protected

        def reject_message_from_key(key)
          I18n.t("discourse_activity_pub.activity.reject.#{key}")
        end
      end
    end
  end
end