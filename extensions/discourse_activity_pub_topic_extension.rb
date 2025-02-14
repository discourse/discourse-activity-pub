# frozen_string_literal: true
module DiscourseActivityPubTopicExtension
  def reload(options = nil)
    @activity_pub_enabled = nil
    @activity_pub_total_posts = nil
    @activity_pub_total_post_count = nil
    @activity_pub_published_posts = nil
    @activity_pub_published_post_count = nil
    @with_deleted_first_post = nil
    super(options)
  end

  def activity_pub_enabled
    @activity_pub_enabled ||= regular? && activity_pub_taxonomy&.activity_pub_ready?
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

  def activity_pub_all_posts_published?
    activity_pub_total_post_count == activity_pub_published_post_count
  end

  def with_deleted_first_post
    @with_deleted_first_post ||= posts.with_deleted.find_by(post_number: 1)
  end

  def activity_pub_published?
    activity_pub_published_at.present?
  end

  def activity_pub_published_at
    return nil unless activity_pub_enabled && with_deleted_first_post
    with_deleted_first_post.activity_pub_published_at
  end

  def activity_pub_scheduled?
    activity_pub_scheduled_at.present?
  end

  def activity_pub_scheduled_at
    unless activity_pub_enabled && with_deleted_first_post &&
             !with_deleted_first_post.activity_pub_published?
      return nil
    end
    with_deleted_first_post.activity_pub_scheduled_at
  end

  def activity_pub_deleted?
    activity_pub_deleted_at.present?
  end

  def activity_pub_deleted_at
    return nil unless activity_pub_enabled && with_deleted_first_post
    with_deleted_first_post.activity_pub_deleted_at
  end

  def activity_pub_delivered?
    activity_pub_delivered_at.present?
  end

  def activity_pub_delivered_at
    return nil unless activity_pub_enabled && with_deleted_first_post
    with_deleted_first_post.activity_pub_delivered_at
  end

  def activity_pub_post_actors
    @activity_pub_post_actors ||=
      begin
        return [] unless activity_pub_enabled && activity_pub_object

        sql = <<~SQL
        SELECT objects.model_id AS post_id, actors.id, actors.username, actors.domain, actors.ap_id
        FROM discourse_activity_pub_objects AS objects
        JOIN discourse_activity_pub_actors AS actors ON actors.ap_id = objects.attributed_to_id
        WHERE objects.collection_id = :collection_id
        ORDER BY objects.model_id
      SQL
        DB.query(sql, collection_id: self.activity_pub_object.id)
      end
  end
end
