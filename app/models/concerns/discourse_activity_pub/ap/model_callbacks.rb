# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ModelCallbacks
      extend ActiveSupport::Concern

      included do
        attr_accessor :performing_activity_stop,
                      :performing_activity_skip_delivery,
                      :performing_activity_delivery_delay
      end

      def perform_activity_pub_activity(activity_type, activity_target_type = nil)
        @performing_activity_type = activity_type
        @performing_activity_target_type = activity_target_type

        performing_activity_before_perform
        unless activity_pub_perform_activity? && performing_activity_actor &&
                 performing_activity_object
          return false
        end

        ActiveRecord::Base.transaction do
          performing_activity_update_object
          performing_activity_create_activity
        end

        performing_activity_before_deliver

        unless performing_activity_skip_delivery
          if performing_activity_can_deliver?
            performing_activity_deliver
          else
            performing_activity.stored.publish! if performing_activity.stored
          end
        end

        performing_activity_after_perform
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

        performing_activity_deliver if performing_activity_can_deliver?
        performing_activity_cleanup

        true
      end

      protected

      def performing_activity
        @performing_activity ||=
          DiscourseActivityPub::AP::Object.from_type(@performing_activity_type)
      end

      def performing_activity_target
        @performing_activity_target ||=
          DiscourseActivityPub::AP::Object.from_type(@performing_activity_target_type)
      end

      def performing_activity_object
        @performing_activity_object ||=
          begin
            return nil unless performing_activity

            case performing_activity.type.downcase.to_sym
            when :update, :delete, :like
              self.activity_pub_object
            when :create
              return self.activity_pub_object if self.activity_pub_object.present?

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
                .find_by(ap_type: performing_activity_target.type)
            else
              nil
            end
          end
      end

      def performing_activity_actor
        @performing_activity_actor ||=
          begin
            if (self.is_a?(Post) || self.is_a?(PostAction)) && self.activity_pub_full_topic
              activity_user = performing_activity.update? ? acting_user : user
              DiscourseActivityPub::ActorHandler.update_or_create_actor(activity_user)
            else
              self.activity_pub_actor
            end
          end
      end

      def performing_activity_before_perform
      end

      def performing_activity_before_deliver
      end

      def performing_activity_after_perform
      end

      def performing_activity_update_object
        return unless performing_activity && performing_activity_object

        if performing_activity.create? || performing_activity.update?
          performing_activity_object.name = self.activity_pub_name if self.activity_pub_name
          performing_activity_object.content = self.activity_pub_content
          performing_activity_object.save!
        end
      end

      def performing_activity_create_activity
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
        @performing_activity_type = nil
        @performing_activity_target_type = nil
        @performing_activity = nil
        @performing_activity_target = nil
        @performing_activity_object = nil
        @performing_activity_actor = nil
        @performing_activity_deliveries = nil
        @performing_activity_skip_delivery = nil
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
    end
  end
end
