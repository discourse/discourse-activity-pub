module DiscourseActivityPubTopicExtension
  def reload(options = nil)
    @activity_pub_total_posts = nil
    @activity_pub_total_post_count = nil
    @activity_pub_published_posts = nil
    @activity_pub_published_post_count = nil
    super(options)
  end

  def activity_pub_total_posts
    @activity_pub_total_posts ||= Post.where(topic_id: self.id,  post_type: Post.types[:regular])
  end

  def activity_pub_published_posts
    @activity_pub_published_posts ||= activity_pub_total_posts.where(
      "posts.id IN (SELECT post_id FROM post_custom_fields WHERE name = 'activity_pub_published_at' AND value IS NOT NULL)"
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
end
