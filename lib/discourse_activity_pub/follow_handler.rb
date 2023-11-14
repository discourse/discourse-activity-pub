# frozen_string_literal: true
module DiscourseActivityPub
    class FollowHandler
        attr_reader :actor,
                    :handle

        def initialize(actor, uri)
            @actor = actor
            @handle = Webfinger::Handle.new(uri)
        end

        def perform
            return false unless handle.valid?
            return false unless follow_actor
            return false unless follow_activity

            deliver
        end

        def self.perform(actor, uri)
            self.new(actor, uri).perform
        end

        protected

        def follow_actor
            @follow_actor ||= DiscourseActivityPubActor.find_by_handle(handle.to_s, refresh: true)
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