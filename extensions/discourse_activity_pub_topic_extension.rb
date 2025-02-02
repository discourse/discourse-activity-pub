# frozen_string_literal: true
module DiscourseActivityPubTopicExtension
  def reload(options = nil)
    @activity_pub_total_posts = nil
    @activity_pub_total_post_count = nil
    @activity_pub_published_posts = nil
    @activity_pub_published_post_count = nil
    @ap_first_post = nil
    super(options)
  end

  def activity_pub_total_posts
    @activity_pub_total_posts ||= Post.where(topic_id: self.id, post_type: Post.types[:regular])
  end

  def activity_pub_published_posts
    @activity_pub_published_posts ||=
      activity_pub_total_posts.where(
        "posts.id IN (SELECT post_id FROM post_custom_fields WHERE name = 'activity_pub_published_at' AND value IS NOT NULL)",
      )
  end

  def activity_pub_total_post_count
    @activity_pub_total_post_count ||= activity_pub_total_posts.count
  end

  def activity_pub_published_post_count
    @activity_pub_published_post_count ||= activity_pub_published_posts.count
  end

  def activity_pub_published?
    activity_pub_total_post_count == activity_pub_published_post_count
  end

  # The break with the naming convention is due to the 'activity_pub_first_post' publication type.
  def ap_first_post
    @ap_first_post ||= posts.with_deleted.find_by(post_number: 1)
  end

  def activity_pub_published_at
    return nil unless activity_pub_enabled && ap_first_post
    ap_first_post.activity_pub_published_at
  end

  def activity_pub_scheduled?
    activity_pub_scheduled_at.present?
  end

  def activity_pub_scheduled_at
    unless activity_pub_enabled && ap_first_post && !ap_first_post.activity_pub_published?
      return nil
    end
    ap_first_post.activity_pub_scheduled_at
  end

  def activity_pub_deleted?
    activity_pub_deleted_at.present?
  end

  def activity_pub_deleted_at
    return nil unless activity_pub_enabled && ap_first_post
    ap_first_post.activity_pub_deleted_at
  end

  def activity_pub_delivered?
    activity_pub_delivered_at.present?
  end

  def activity_pub_delivered_at
    return nil unless activity_pub_enabled && ap_first_post
    ap_first_post.activity_pub_delivered_at
  end
end
