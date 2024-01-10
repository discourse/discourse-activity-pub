# frozen_string_literal: true
module DiscourseActivityPub
  module AP
    module ModelHelpers
      extend ActiveSupport::Concern

      def clear_all_activity_pub_objects
        ActiveRecord::Base.transaction do
          if self.respond_to?(:before_clear_all_activity_pub_objects)
            self.before_clear_all_activity_pub_objects
          end

          objects = DiscourseActivityPubObject.where(model_id: self.id, model_type: self.class.name)
          objects.each do |object|
            object.activities.each do |activity|
              activity_job_args = {
                object_id: activity.id,
                object_type: "DiscourseActivityPubActivity",
                from_actor_id: activity.actor.id,
              }
              activity.actor.followers.each do |follower|
                activity_job_args[:to_actor_id] = follower.id
                Jobs.cancel_scheduled_job(:discourse_activity_pub_deliver, **activity_job_args)
              end
            end
            object.activities.destroy_all
          end
          objects.destroy_all
        end

        collections =
          DiscourseActivityPubCollection.where(model_id: self.id, model_type: self.class.name)
        collections.each do |collection|
          object_job_args = {
            object_id: collection.id,
            object_type: "DiscourseActivityPubCollection",
            from_actor_id: self.activity_pub_actor.id,
          }
          self.activity_pub_actor.followers.each do |follower|
            object_job_args[:to_actor_id] = follower.id
            Jobs.cancel_scheduled_job(:discourse_activity_pub_deliver, **object_job_args)
          end
        end
      end
    end
  end
end
