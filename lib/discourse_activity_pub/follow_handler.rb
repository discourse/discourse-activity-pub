# frozen_string_literal: true
module DiscourseActivityPub
    class FollowHandler
        attr_reader :actor
        attr_accessor :follow_actor

        def initialize(actor_id)
            @actor = DiscourseActivityPubActor.find_by_id(actor_id)
        end

        def perform(follow_actor_id)
            return false unless actor

            @follow_actor = DiscourseActivityPubActor.find_by_id(follow_actor_id)

            return false unless follow_actor&.remote?
            return false unless follow_activity

            deliver
        end

        def self.perform(actor_id, follow_actor_id)
            self.new(actor_id).perform(follow_actor_id)
        end

        protected

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
                recipients: [follow_actor]
            )
        end
    end
end