# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ModelCallbacks
      extend ActiveSupport::Concern

      included do
        attr_accessor :performing_activity,
                      :performing_activity_object
      end

      def perform_activity_pub_activity(activity_type)
        @performing_activity = DiscourseActivityPub::AP::Object.from_type(activity_type)
        return unless valid_activity_pub_activity?

        if self.respond_to?(:before_perform_activity_pub_activity)
          @performing_activity = before_perform_activity_pub_activity(
            performing_activity
          )
          return unless performing_activity
        end

        @performing_activity_object = get_performing_activity_object
        return unless performing_activity_object

        ActiveRecord::Base.transaction do
          update_activity_pub_activity_object
          create_activity_pub_activity
        end

        perform_activity_pub_activity_cleanup
      end

      protected

      def valid_activity_pub_activity?
        return false unless self.activity_pub_enabled && performing_activity&.composition?

        # We don't permit updates if object has been deleted.
        return false if self.activity_pub_deleted? && performing_activity.update?

        true
      end

      def get_performing_activity_object
        return nil unless performing_activity

        case performing_activity.type.downcase.to_sym
        when :update, :delete
          self.activity_pub_object
        when :create
          self.build_activity_pub_object(local: true)
        else
          nil
        end
      end

      def update_activity_pub_activity_object
        return unless performing_activity

        if performing_activity.create? || performing_activity.update?
          performing_activity_object.content = self.activity_pub_content
          performing_activity_object.save!
        end
      end

      def create_activity_pub_activity
        return if !performing_activity || (
          performing_activity.update? && !self.activity_pub_published?
        )

        visibility = DiscourseActivityPubActivity.visibilities[
          self.activity_pub_visibility.to_sym
        ] || DiscourseActivityPubActivity.visibilities[
          DiscourseActivityPubActivity::DEFAULT_VISIBILITY.to_sym
        ]

        activity_attrs = {
          local: true,
          actor_id: self.activity_pub_actor.id,
          object_id: performing_activity_object.id,
          object_type: performing_activity_object.class.name,
          ap_type: performing_activity.type,
          visibility: visibility
        }

        activity_attrs[:visibility] = DiscourseActivityPubActivity.visibilities[
          self.activity_pub_visibility.to_sym
        ] if self.activity_pub_visibility

        return if DiscourseActivityPubActivity.exists?(
          activity_attrs.merge(published_at: nil)
        )

        DiscourseActivityPubActivity.create!(activity_attrs)
      end

      def perform_activity_pub_activity_cleanup
        @performing_activity = nil
        @performing_activity_object = nil
      end
    end
  end
end