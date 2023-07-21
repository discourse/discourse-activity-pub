# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    module ActivityValidations
      extend ActiveSupport::Concern
      include IdentifierValidations

      included do
        validates :actor_id, presence: true
        validate :validate_object_type, if: :will_save_change_to_object_type?
        validate :validate_ap_type,
                 if: Proc.new { |a| a.will_save_change_to_ap_type? || a.will_save_change_to_object_type? }
      end

      def validate_object_type
        unless supported_object_types.include?(object_type)
          self.errors.add(
            :object_type,
            I18n.t("activerecord.errors.models.discourse_activity_pub_activity.attributes.object_type.invalid")
          )
        end
      end

      def validate_ap_type
        return unless actor
        object_ap_type = object&.respond_to?(:ap_type) ? object.ap_type : nil

        unless actor.can_perform_activity?(ap_type, object_ap_type)
          self.errors.add(
            :ap_type,
            I18n.t("activerecord.errors.models.discourse_activity_pub_activity.attributes.ap_type.invalid")
          )
        end
      end

      def supported_object_types
        %w(DiscourseActivityPubActivity DiscourseActivityPubActor DiscourseActivityPubObject)
      end
    end
  end
end