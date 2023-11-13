# frozen_string_literal: true
module DiscourseActivityPub
    class FollowHandler
        attr_reader :actor,
                    :handle,
                    :username,
                    :domain

        def initialize(actor, handle)
            @actor = actor
            @handle = handle

            username, domain = handle.split('@')
            @username = username
            @domain = domain
        end

        def perform
            return false if DiscourseActivityPub::URI.local?(domain)
            return false unless follow_actor
            return false unless follow_activity

            deliver
        end

        def self.perform(actor, handle)
            self.new(actor, handle).perform
        end

        protected

        def follow_actor
            @follow_actor ||= DiscourseActivityPubActor.find_by_handle(handle)
        end

        def follow_activity
            @follow_activity ||= DiscourseActivityPubActivity.create!(
                local: true,
                actor_id: actor.id,
                object_id: follow_actor.id,
                object_type: follow_actor.class.name,
                ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
            )
        end

        def deliver
            DiscourseActivityPub::DeliveryHandler.perform(
                actor: actor,
                object: follow_activity,
                recipients: [follow_actor.ap_id]
            )
        end
    end
end