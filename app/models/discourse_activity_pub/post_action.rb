# frozen_string_literal: true
module DiscourseActivityPub::PostAction
  def self.prepended(post_action_class)
    post_action_class.include DiscourseActivityPub::AP::ModelCallbacks
  end

  def activity_pub_enabled
    post.activity_pub_enabled
  end

  def activity_pub_perform_activity?
    return false if performing_activity_stop
    return false unless activity_pub_enabled
    return false unless activity_pub_full_topic
    performing_activity&.like? || (performing_activity&.undo? && performing_activity_target&.like?)
  end

  def activity_pub_deleted?
    nil
  end

  def activity_pub_published?
    !!post.activity_pub_published_at
  end

  def activity_pub_visibility
    "public"
  end

  def activity_pub_actor
    user.activity_pub_actor
  end

  def performing_activity_delivery_delay
    post.performing_activity_delivery_delay
  end

  def activity_pub_taxonomy_actors
    post.activity_pub_taxonomy_actors
  end

  def activity_pub_object
    post.activity_pub_object
  end

  def activity_pub_full_topic
    post.activity_pub_full_topic
  end

  def activity_pub_first_post
    post.activity_pub_first_post
  end

  def activity_pub_topic_published?
    post.activity_pub_topic_published?
  end

  def activity_pub_collection
    post.activity_pub_collection
  end

  def performing_activity_before_deliver
    if !self.destroyed? && !activity_pub_published? && !performing_activity.create?
      @performing_activity_skip_delivery = true
    end
  end
end
