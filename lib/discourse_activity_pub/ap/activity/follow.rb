# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Follow < Activity
        def type
          'Follow'
        end

        def respond_to_activity
          response = AP::Activity::Response.new
          response.reject(message: stored.errors.full_messages.join(', ')) if stored.errors.any?
          response.reject(key: "actor_already_following") if actor.stored.following?(object.stored)

          response.stored = DiscourseActivityPubActivity.create!(
            local: true,
            ap_type: response.type,
            actor_id: object.stored.id,
            object_id: stored.id,
            object_type: 'DiscourseActivityPubActivity',
            summary: response.summary
          )

          if response.accepted?
            DiscourseActivityPubFollow.create!(
              follower_id: actor.stored.id,
              followed_id: object.stored.id
            )
          end

          DiscourseActivityPub::DeliveryHandler.perform(
            object.stored,
            response.stored,
            0
          )
        end
      end
    end
  end
end
