# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module TypeValidations
      extend ActiveSupport::Concern

      included do
        before_validation :ensure_ap_type
        validates :ap_type, presence: true
      end

      def ap
        @ap ||= DiscourseActivityPub::AP::Object.get_klass(ap_type)&.new(stored: self)
      end

      def _model
        self.respond_to?(:model) ? self.model : self.actor.model
      end

      def ensure_ap_type
        self.ap_type = _model.activity_pub_default_object_type if !self.ap_type && _model.present?

        unless ap
          self.errors.add(
            :ap_type,
            I18n.t(
              "activerecord.errors.models.discourse_activity_pub_activity.attributes.ap_type.invalid",
            ),
          )

          raise ActiveRecord::RecordInvalid
        end

        self.ap_type = ap.type
      end
    end
  end
end
