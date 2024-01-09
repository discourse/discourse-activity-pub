# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ModelCallbacks
      extend ActiveSupport::Concern

      included do
        attr_accessor :performing_activity,
                      :performing_activity_object,
                      :performing_activity_actor,
                      :target_activity
      end

      def perform_activity_pub_activity(activity_type, target_activity_type = nil)
        return nil unless DiscourseActivityPub.publishing_enabled

        @performing_activity = DiscourseActivityPub::AP::Object.from_type(activity_type)
        @target_activity =
          DiscourseActivityPub::AP::Object.from_type(target_activity_type) if target_activity_type
        return unless valid_activity_pub_activity?

        if self.respond_to?(:before_perform_activity_pub_activity)
          @performing_activity = before_perform_activity_pub_activity(performing_activity)
          return true unless performing_activity
        end

        @performing_activity_object = get_performing_activity_object
        return unless performing_activity_object

        @performing_activity_actor = get_performing_activity_actor
        return unless performing_activity_actor

        ActiveRecord::Base.transaction do
          update_activity_pub_activity_object
          create_activity_pub_activity
        end

        activity_pub_deliver_activity
        perform_activity_pub_activity_cleanup

        true
      end

      protected

      def valid_activity_pub_activity?
        return false unless activity_pub_enabled
        return false unless activity_pub_valid_activity?(performing_activity, target_activity)

        # We don't permit updates if object has been deleted.
        return false if self.activity_pub_deleted? && performing_activity.update?

        # Can't have an activity without an actor.
        return false unless self.activity_pub_actor

        true
      end

      def get_performing_activity_object
        return nil unless performing_activity

        case performing_activity.type.downcase.to_sym
        when :update, :delete, :like
          self.activity_pub_object
        when :create
          attrs = { local: true }
          if self.activity_pub_reply_to_object
            attrs[:reply_to_id] = self.activity_pub_reply_to_object.ap_id
          end
          if self.activity_pub_full_topic
            attrs[:collection_id] = self.topic.activity_pub_object.id
            attrs[:attributed_to_id] = self.activity_pub_actor.ap_id
          end
          self.build_activity_pub_object(attrs)
        when :undo
          activity_pub_actor
            .activities
            .where(object_id: self.activity_pub_object.id)
            .find_by(ap_type: target_activity.type)
        else
          nil
        end
      end

      def get_performing_activity_actor
        if !self.respond_to?(:acting_user) || acting_user.blank? || !performing_activity.update? ||
             !self.activity_pub_full_topic
          return self.activity_pub_actor
        end

        unless acting_user.activity_pub_actor.present?
          DiscourseActivityPub::UserHandler.update_or_create_actor(acting_user)
        end

        acting_user.activity_pub_actor
      end

      def update_activity_pub_activity_object
        return unless performing_activity

        if performing_activity.create? || performing_activity.update?
          performing_activity_object.name = self.activity_pub_name if self.activity_pub_name
          performing_activity_object.content = self.activity_pub_content
          performing_activity_object.save!
        end
      end

      def create_activity_pub_activity
        if !performing_activity || (performing_activity.update? && !self.activity_pub_published?)
          return
        end

        activity_attrs = {
          local: true,
          actor_id: performing_activity_actor.id,
          object_id: performing_activity_object.id,
          object_type: performing_activity_object.class.name,
          ap_type: performing_activity.type,
        }

        activity_attrs[:visibility] = DiscourseActivityPubActivity.visibilities[
          self.activity_pub_visibility.to_sym
        ] if self.activity_pub_visibility

        return if DiscourseActivityPubActivity.exists?(activity_attrs.merge(published_at: nil))

        @performing_activity.stored = DiscourseActivityPubActivity.create!(activity_attrs)
      end

      def activity_pub_deliver_activity
        return if !activity_pub_delivery_object

        if activity_pub_schedule?
          if self.respond_to?(:activity_pub_after_scheduled)
            activity_pub_after_scheduled(scheduled_at: activity_pub_first_post_scheduled_at)
          end
          return
        end

        DiscourseActivityPub::DeliveryHandler.perform(
          actor: activity_pub_delivery_actor,
          object: activity_pub_delivery_object,
          recipient_ids: activity_pub_delivery_recipient_ids,
          delay: activity_pub_delivery_delay,
        )
      end

      def perform_activity_pub_activity_cleanup
        @performing_activity = nil
        @performing_activity_object = nil
        @performing_activity_actor = nil
      end

      def activity_pub_delivery_recipient_ids
        @activity_pub_delivery_recipient_ids ||=
          begin
            actor_ids = activity_pub_group_actor.reload.followers.map(&:id)

            if self.respond_to?(:activity_pub_collection) && activity_pub_collection.present?
              activity_pub_collection
                .contributors(local: false)
                .each do |contributor|
                  if actor_ids.exclude?(contributor.id) &&
                       contributor.id != performing_activity_actor.id
                    actor_ids << contributor.id
                  end
                end
            end

            actor_ids
          end
      end

      def activity_pub_schedule?
        !self.destroyed? && activity_pub_full_topic && !activity_pub_topic_published? &&
          (!activity_pub_is_first_post? || !performing_activity.create?)
      end

      def activity_pub_delivery_actor
        if performing_activity.create?
          activity_pub_group_actor
        else
          performing_activity_actor
        end
      end

      def activity_pub_delivery_object
        if !self.destroyed? && !activity_pub_topic_published? && activity_pub_full_topic
          activity_pub_collection.activities_collection
        else
          performing_activity.stored
        end
      end

      def activity_pub_delivery_delay
        if !self.destroyed? && !activity_pub_topic_published?
          SiteSetting.activity_pub_delivery_delay_minutes.to_i
        else
          nil
        end
      end
    end
  end
end
