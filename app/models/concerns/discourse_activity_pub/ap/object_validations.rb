# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    module ObjectValidations
      extend ActiveSupport::Concern

      included { validate :validate_object_type, if: :will_save_change_to_object_type? }

      def validate_object_type
        if supported_object_types.exclude?(object_type)
          self.errors.add(
            :object_type,
            I18n.t(
              "activerecord.errors.models.discourse_activity_pub_object.attributes.object_type.invalid",
            ),
          )
        end
      end

      def supported_object_types
        %w[DiscourseActivityPubActivity DiscourseActivityPubActor DiscourseActivityPubObject]
      end
    end
  end
end
