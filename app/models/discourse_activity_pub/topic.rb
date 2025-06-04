# frozen_string_literal: true
module DiscourseActivityPub::Topic
  def self.prepended(topic_class)
    topic_class.include DiscourseActivityPub::AP::ModelHelpers
    topic_class.include DiscourseActivityPub::AP::ModelCallbacks
    topic_class.has_one :activity_pub_object,
                        class_name: "DiscourseActivityPubCollection",
                        as: :model
    topic_class.after_destroy :cache_activity_pub_after_destroy
  end

  def reload(options = nil)
    @activity_pub_enabled = nil
    @activity_pub_taxonomies = nil
    @activity_pub_taxonomy = nil
    @activity_pub_actor = nil
    @activity_pub_visibility = nil
    @activity_pub_total_posts = nil
    @activity_pub_total_post_count = nil
    @activity_pub_published_posts = nil
    @activity_pub_published_post_count = nil
    @with_deleted_first_post = nil
    super(options)
  end

  def cache_activity_pub_after_destroy
    @activity_pub_enabled = self.activity_pub_enabled
    @activity_pub_actor = self.activity_pub_actor
    @activity_pub_visibility = self.activity_pub_visibility
    @activity_pub_taxonomies = self.activity_pub_taxonomies
    @activity_pub_full_topic = self.activity_pub_full_topic
    @activity_pub_first_post = self.activity_pub_first_post
  end

  def activity_pub_ready?
    activity_pub_enabled && (activity_pub_first_post || activity_pub_full_topic)
  end

  def activity_pub_enabled
    @activity_pub_enabled ||=
      regular? && activity_pub_taxonomy&.activity_pub_ready? &&
        (!category || category.activity_pub_allowed?)
  end

  def activity_pub_taxonomies
    @activity_pub_taxonomies ||= [*tags, category].select { |t| t&.activity_pub_actor.present? }
  end

  def activity_pub_taxonomy
    @activity_pub_taxonomy ||= activity_pub_taxonomies.sort_by { |t| t.is_a?(Tag) ? -1 : 1 }.first
  end

  def activity_pub_actor
    @activity_pub_actor ||= activity_pub_taxonomy&.activity_pub_actor
  end

  def activity_pub_full_url
    "#{DiscourseActivityPub.base_url}#{self.relative_url}"
  end

  def activity_pub_first_post
    @activity_pub_first_post ||= activity_pub_taxonomy&.activity_pub_first_post
  end

  def activity_pub_full_topic
    @activity_pub_full_topic ||= activity_pub_taxonomy&.activity_pub_full_topic
  end

  def activity_pub_full_topic_enabled
    activity_pub_enabled && activity_pub_full_topic
  end

  def create_activity_pub_collection!
    params = { local: true, ap_type: activity_pub_default_object_type, name: activity_pub_name }
    attributed_to = DiscourseActivityPub::ActorHandler.update_or_create_actor(self.user)
    params[:attributed_to_id] = attributed_to.ap_id if attributed_to
    create_activity_pub_object!(params)
  end

  def activity_pub_activities_collection
    activity_pub_object.activities_collection
  end

  def activity_pub_objects_collection
    activity_pub_object.objects_collection
  end

  def activity_pub_name
    self.title
  end

  def activity_pub_local?
    !first_post&.activity_pub_object || first_post.activity_pub_object.local
  end

  def activity_pub_remote?
    !activity_pub_local?
  end

  def activity_pub_publish!
    return false if activity_pub_published?
    Jobs.enqueue(Jobs::DiscourseActivityPub::Publish, topic_id: self.id)
  end

  def activity_pub_publish_state
    model = {
      id: self.id,
      type: "topic",
      activity_pub_published: self.activity_pub_published?,
      activity_pub_published_post_count: self.activity_pub_published_post_count,
      activity_pub_total_post_count: self.activity_pub_total_post_count,
      activity_pub_scheduled_at: self.activity_pub_scheduled_at,
      activity_pub_published_at: self.activity_pub_published_at,
      activity_pub_deleted_at: self.activity_pub_deleted_at,
      activity_pub_delivered_at: self.activity_pub_delivered_at,
    }
    MessageBus.publish("/activity-pub", { model: model })
  end

  def activity_pub_default_object_type
    DiscourseActivityPub::AP::Collection::OrderedCollection.type
  end

  def activity_pub_delete!
    return false unless activity_pub_local?
    perform_activity_pub_activity(:delete)
  end

  def activity_pub_perform_activity?
    return false if performing_activity_stop
    return false unless DiscourseActivityPub.publishing_enabled && activity_pub_enabled
    performing_activity&.delete?
  end

  def performing_activity_after_perform
    if performing_activity.delete? && performing_activity_object
      if !performing_activity_object.model || performing_activity_object.model.destroyed?
        performing_activity_object.destroy!
      else
        performing_activity_object.tombstone!
      end
    end
  end

  def activity_pub_visibility
    @activity_pub_visibility ||= "public"
  end

  def activity_pub_total_posts
    @activity_pub_total_posts ||= ::Post.where(topic_id: self.id, post_type: ::Post.types[:regular])
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
