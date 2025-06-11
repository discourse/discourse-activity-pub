# frozen_string_literal: true
module DiscourseActivityPub
  class FollowHandler
    attr_reader :actor, :target_actor

    def initialize(actor_id, target_actor_id)
      @actor = DiscourseActivityPubActor.find_by_id(actor_id)
      @target_actor = DiscourseActivityPubActor.find_by_id(target_actor_id)
    end

    def follow
      return false unless actor && target_actor&.remote?
      return false unless actor.can_follow?(target_actor)
      return false unless follow_activity

      deliver(follow_activity)
    end

    def unfollow
      return false unless actor && target_actor&.remote?
      return false unless actor.following?(target_actor)
      return false unless unfollow_object
      return false unless unfollow_activity

      # The follow itself is destroyed in DiscourseActivityPubActivity.after_deliver

      deliver(unfollow_activity)
    end

    def reject
      return false unless actor && target_actor&.remote?
      return false unless target_actor.following?(actor)
      return false unless reject_object
      return false unless reject_activity

      # Destroy follow on reject, regardless of whether delivery succeeds.
      destroy_follow

      deliver(reject_activity)
    end

    def self.follow(actor_id, target_actor_id)
      self.new(actor_id, target_actor_id).follow
    end

    def self.unfollow(actor_id, target_actor_id)
      self.new(actor_id, target_actor_id).unfollow
    end

    def self.reject(actor_id, target_actor_id)
      self.new(actor_id, target_actor_id).reject
    end

    protected

    def follow_activity
      @follow_activity ||=
        DiscourseActivityPubActivity.find_or_create_by(
          local: true,
          actor_id: actor.id,
          object_id: target_actor.id,
          object_type: target_actor.class.name,
          ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
          published_at: nil,
        )
    end

    def unfollow_object
      @unfollow_object ||=
        DiscourseActivityPubActivity
          .where(
            local: true,
            actor_id: actor.id,
            object_id: target_actor.id,
            object_type: target_actor.class.name,
            ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
          )
          .where.not(published_at: nil)
          .order(published_at: :desc)
          .first
    end

    def unfollow_activity
      @unfollow_activity ||=
        DiscourseActivityPubActivity.find_or_create_by(
          local: true,
          actor_id: actor.id,
          object_id: unfollow_object.id,
          object_type: unfollow_object.class.name,
          ap_type: DiscourseActivityPub::AP::Activity::Undo.type,
          published_at: nil,
        )
    end

    def reject_object
      @reject_object ||=
        DiscourseActivityPubActivity
          .where(
            local: nil,
            actor_id: target_actor.id,
            object_id: actor.id,
            object_type: actor.class.name,
            ap_type: DiscourseActivityPub::AP::Activity::Follow.type,
          )
          .where.not(published_at: nil)
          .order(published_at: :desc)
          .first
    end

    def reject_activity
      @reject_activity ||=
        DiscourseActivityPubActivity.find_or_create_by(
          local: true,
          actor_id: actor.id,
          object_id: reject_object.id,
          object_type: reject_object.class.name,
          ap_type: DiscourseActivityPub::AP::Activity::Reject.type,
          published_at: nil,
        )
    end

    def deliver(object)
      DiscourseActivityPub::DeliveryHandler.perform(
        actor: actor,
        object: object,
        recipient_ids: [target_actor.id],
      )
    end

    def destroy_follow
      DiscourseActivityPubFollow.where(
        follower_id: target_actor.id,
        followed_id: actor.id,
      ).destroy_all
    end
  end
end
