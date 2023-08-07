# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module IdentifierValidations
      extend ActiveSupport::Concern
      include JsonLd

      included do
        before_validation :ensure_ap_type
        before_validation :ensure_ap_key, if: :local?
        before_validation :ensure_ap_id, if: :local?

        validates :ap_type, presence: true
        validates :ap_key, uniqueness: true, allow_nil: true # foreign objects don't have keys
        validates :ap_id, uniqueness: true, presence: true
      end

      def ap
        @ap ||= DiscourseActivityPub::AP::Object.get_klass(ap_type)&.new(stored: self)
      end

      def local?
        !!self.local
      end

      def _model
        self.respond_to?(:model) ? self.model : self.actor.model
      end

      def ensure_ap_type
        self.ap_type = _model.activity_pub_default_object_type if !self.ap_type

        unless ap
          self.errors.add(
            :ap_type,
            I18n.t("activerecord.errors.models.discourse_activity_pub_activity.attributes.ap_type.invalid")
          )

          raise ActiveRecord::RecordInvalid
        end

        self.ap_type = ap.type
      end

      def ensure_ap_key
        self.ap_key = generate_key if !self.ap_key
      end

      def ensure_ap_id
        self.ap_id = json_ld_id(ap.base_type, ap_key) if !self.ap_id
      end
    end
  end
end