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
            model_actor = model.activity_pub_actor
            ap_response = AP::Activity::Response.new

            @activity = DiscourseActivityPubActivity.create!(
              uid: json[:id],
              ap_type: type,
              actor_id: actor.id,
              object_id: model_actor.id,
              object_type: 'DiscourseActivityPubActor'
            )

            ap_response.reject(message: activity.errors.full_messages.join(', ')) if activity.errors.any?
            ap_response.reject(key: "actor_already_following") if actor.following?(model)

            ap_response.activity = DiscourseActivityPubActivity.create!(
              ap_type: ap_response.type,
              actor_id: model_actor.id,
              object_id: activity.id,
              object_type: 'DiscourseActivityPubActivity',
              summary: ap_response.summary
            )

            if ap_response.accepted?
              DiscourseActivityPubFollow.create!(
                follower_id: actor.id,
                followed_id: model_actor.id
              )
            end

            deliver_ap_response(actor.inbox, ap_response)
          end
        end
      end
    end
  end
end
