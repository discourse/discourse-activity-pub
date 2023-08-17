# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ModelValidations
      extend ActiveSupport::Concern

      included do
        validate :validate_model_type, if: :will_save_change_to_model_type?
      end

      def can_belong_to?(model_type)
        return false unless ap && model_type
        ap.can_belong_to.include?(model_type.downcase.to_sym)
      end

      def validate_model_type
        @ap = nil
        unless can_belong_to?(model_type)
          self.errors.add(
            :ap_type,
            I18n.t("activerecord.errors.models.discourse_activity_pub.attributes.model_type.invalid")
          )
        end
      end
    end
  end
end