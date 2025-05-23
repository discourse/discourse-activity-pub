# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ModelCallbacks
      extend ActiveSupport::Concern

      included do
        attr_accessor :performing_activity,
                      :performing_activity_object,
                      :performing_activity_actor,
                      :performing_activity_target_activity
        attr_writer :performing_activity_delivery_delay
      end

      def perform_activity_pub_activity(activity_type, target_activity_type = nil)
        return false unless activity_pub_publishing_enabled

        @performing_activity = DiscourseActivityPub::AP::Object.from_type(activity_type)

        if self.respond_to?(:before_perform_activity_pub_activity)
          @performing_activity = before_perform_activity_pub_activity(performing_activity)
          return true unless performing_activity
        end

        return false unless activity_pub_perform_activity?

        @performing_activity_target_activity =
          DiscourseActivityPub::AP::Object.from_type(target_activity_type) if target_activity_type
        return false unless valid_activity_pub_activity?

        return false unless ensure_activity_pub_actor

        @performing_activity_object = get_performing_activity_object
        return false unless performing_activity_object

        @performing_activity_actor = get_performing_activity_actor
        return false unless performing_activity_actor

        ActiveRecord::Base.transaction do
          update_activity_pub_activity_object
          create_activity_pub_activity
        end

        if performing_activity_pre_publication?
          if self.respond_to?(:activity_pub_after_scheduled)
            activity_pub_after_scheduled(scheduled_at: activity_pub_scheduled_at)
          end
          return true
        end

        if performing_activity_can_deliver?
          performing_activity_deliver
        else
          @performing_activity.stored.publish! if @performing_activity.stored
        end

        performing_activity_cleanup

        true
      end

      def activity_pub_deliver_create
        return unless activity_pub_object

        @performing_activity =
          DiscourseActivityPub::AP::Activity::Create.new(
            stored: activity_pub_object.create_activity,
          )
        @performing_activity_object = activity_pub_object
        @performing_activity_actor = activity_pub_actor

        return unless performing_activity_can_deliver?

        performing_activity_deliver
        performing_activity_cleanup

        true
      end

      protected

      def valid_activity_pub_activity?
        return false unless activity_pub_enabled
        unless activity_pub_valid_activity?(
                 performing_activity,
                 performing_activity_target_activity,
               )
          return false
        end

        # We don't permit updates if object has been deleted.
        return false if self.activity_pub_deleted? && performing_activity.update?

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
            return nil unless self.topic.activity_pub_object
            attrs[:collection_id] = self.topic.activity_pub_object.id
            attrs[:attributed_to_id] = self.activity_pub_actor.ap_id
          end
          self.build_activity_pub_object(attrs)
        when :undo
          activity_pub_actor
            .activities
            .where(object_id: self.activity_pub_object.id)
            .find_by(ap_type: performing_activity_target_activity.type)
        else
          nil
        end
      end

      def get_performing_activity_actor
        if !self.respond_to?(:acting_user) || acting_user.blank? || !performing_activity.update? ||
             !self.activity_pub_full_topic
          return self.activity_pub_actor
        end

        if acting_user.activity_pub_actor.blank?
          DiscourseActivityPub::ActorHandler.update_or_create_actor(acting_user)
        end

        acting_user.activity_pub_actor
      end

      def performing_activity_pre_publication?
        !self.destroyed? && !activity_pub_published? && !performing_activity.create?
      end

      def update_activity_pub_activity_object
        return unless performing_activity && performing_activity_object

        if performing_activity.create? || performing_activity.update?
          performing_activity_object.name = self.activity_pub_name if self.activity_pub_name
          performing_activity_object.content = self.activity_pub_content

          if self.activity_pub_attachments.present?
            self.activity_pub_attachments.each do |attachment|
              performing_activity_object.attachments.build(
                object_id: performing_activity_object.id,
                object_type: performing_activity_object.class.name,
                ap_type: attachment.type,
                url: attachment.url.href,
                name: attachment.name,
                media_type: attachment.media_type,
              )
            end
          end

          performing_activity_object.save!
        end
      end

      def create_activity_pub_activity
        return unless performing_activity

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

      def performing_activity_can_deliver?
        performing_activity&.stored && performing_activity_deliveries.present?
      end

      def performing_activity_deliveries
        @performing_activity_deliveries ||=
          begin
            deliveries = []
            recipient_ids = []

            performing_activity_delivery_actors.each do |delivery_actor|
              delivery_actor_actor_recipient_ids =
                performing_activity_delivery_recipient_ids(delivery_actor).select do |recipient_id|
                  recipient_ids.exclude?(recipient_id)
                end

              if delivery_actor_actor_recipient_ids.present?
                recipient_ids += delivery_actor_actor_recipient_ids
                deliveries << OpenStruct.new(
                  actor: delivery_actor,
                  object: performing_activity&.stored,
                  recipient_ids: delivery_actor_actor_recipient_ids,
                  delay: performing_activity_delivery_delay,
                )
              end
            end

            deliveries
          end
      end

      def performing_activity_delivery_actors
        if performing_activity_announce?
          activity_pub_taxonomy_actors
        else
          [performing_activity_actor]
        end
      end

      def performing_activity_announce?
        performing_like = performing_activity.like? || performing_activity.undo_like?
        preforming_create_first_post = performing_activity.create? && is_first_post?
        preforming_create_first_post || performing_like
      end

      def performing_activity_deliver
        return unless performing_activity_can_deliver?

        performing_activity_deliveries.each do |delivery|
          DiscourseActivityPub::DeliveryHandler.perform(
            actor: delivery.actor,
            object: delivery.object,
            recipient_ids: delivery.recipient_ids,
            delay: delivery.delay,
          )
        end
      end

      def performing_activity_cleanup
        @performing_activity = nil
        @performing_activity_target_activity = nil
        @performing_activity_object = nil
        @performing_activity_actor = nil
        @performing_activity_deliveries = nil
        @performing_activity_delivery_delay = nil
      end

      def performing_activity_delivery_recipient_ids(delivery_actor)
        actor_ids = delivery_actor.reload.followers.map(&:id)

        if delivery_actor.ap.person?
          activity_pub_taxonomy_actors.each do |taxonomy_actor|
            taxonomy_actor
              .reload
              .followers
              .map(&:id)
              .each { |actor_id| actor_ids << actor_id if actor_ids.exclude?(actor_id) }
          end
        end

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

        actor_ids.uniq
      end

      def performing_activity_delivery_delay
        @performing_activity_delivery_delay ||=
          begin
            if !self.destroyed? && !activity_pub_topic_published?
              SiteSetting.activity_pub_delivery_delay_minutes.to_i
            else
              nil
            end
          end
      end

      def ensure_activity_pub_actor
        return self.activity_pub_actor.present? if self.activity_pub_first_post
        DiscourseActivityPub::ActorHandler.update_or_create_actor(user)
      end
    end
  end
end
