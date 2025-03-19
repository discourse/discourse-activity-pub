# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module IdentifierValidations
      extend ActiveSupport::Concern
      include JsonLd
      include TypeValidations

      included do
        before_validation :ensure_ap_key, if: :local?
        before_validation :ensure_ap_id, if: :local?

        validates :ap_key, uniqueness: true, allow_nil: true # foreign objects don't have keys
        validates :ap_id, uniqueness: true, presence: true
      end

      def local?
        !!self.local
      end

      def remote?
        !local?
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
