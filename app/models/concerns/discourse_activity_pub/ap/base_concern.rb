# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module BaseConcern
      extend ActiveSupport::Concern

      included do
        before_validation :ensure_ap_type
        before_validation :ensure_uid

        validates :uid, presence: true, uniqueness: true
        validates :ap_type, presence: true
      end

      def ap
        @ap ||= DiscourseActivityPub::AP::Object.get_klass(ap_type)&.new(stored: self)
      end

      def _model
        self.respond_to?(:model) ? self.model : self.actor.model
      end

      def ensure_ap_type
        self.ap_type = DiscourseActivityPub::Model.ap_type(_model) if !self.ap_type
      end

      def ensure_uid
        self.uid = DiscourseActivityPub::JsonLd.json_ld_id(_model, ap.base_type) if !self.uid && ap
      end
    end
  end
end