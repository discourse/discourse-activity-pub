# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Response < Activity
        include HasErrors

        def type
          return activity.ap_type if activity.present?
          rejected? ? AP::Activity::Reject.type : AP::Activity::Accept.type
        end

        def summary
          return activity.summary if activity.present?
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