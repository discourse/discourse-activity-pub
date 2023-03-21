# frozen_string_literal: true

module DiscourseActivityPub
  module AP
    class Activity
      class Follow < Activity
        def type
          'Follow'
        end

        def process
          actor, model = process_json
          return false unless actor && model

          ActiveRecord::Base.transaction do
            response = AP::Activity::Response.new
            followed_actor = model.activity_pub_actor

            @stored = DiscourseActivityPubActivity.create!(
              uid: json[:id],
              ap_type: type,
              actor_id: actor.id,
              object_id: followed_actor.id,
              object_type: 'DiscourseActivityPubActor'
            )

            response.reject(message: stored.errors.full_messages.join(', ')) if stored.errors.any?
            response.reject(key: "actor_already_following") if actor.following?(model)

            response.stored = DiscourseActivityPubActivity.create!(
              ap_type: response.type,
              actor_id: followed_actor.id,
              object_id: stored.id,
              object_type: 'DiscourseActivityPubActivity',
              summary: response.summary
            )

            if response.accepted?
              DiscourseActivityPubFollow.create!(
                follower_id: actor.id,
                followed_id: followed_actor.id
              )
            end

            response.deliver(actor.inbox)
          end
        end
      end
    end
  end
end
