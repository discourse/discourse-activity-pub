# frozen_string_literal: true
module DiscourseActivityPub::Post
  module ClassMethods
    def activity_pub_custom_fields
      %i[delivered_at scheduled_at published_at deleted_at updated_at visibility]
    end

    def activity_pub_custom_field_names
      activity_pub_custom_fields.map { |field_name| "activity_pub_#{field_name}" }
    end
  end

  def self.prepended(post_class)
    post_class.extend(ClassMethods)
    post_class.include DiscourseActivityPub::AP::ModelCallbacks
    post_class.include DiscourseActivityPub::AP::ModelHelpers
    post_class.has_one :activity_pub_object, class_name: "DiscourseActivityPubObject", as: :model
    post_class.after_destroy :cache_activity_pub_after_destroy
  end

  def reload
    @activity_pub_enabled = nil
    @activity_pub_actor = nil
    @activity_pub_full_topic = nil
    @activity_pub_first_post = nil
    @activity_pub_visibility = nil
    @activity_pub_taxonomy_actors = nil
    @activity_pub_taxonomy_followers = nil
    @activity_pub_topic_trashed = nil
    super
  end

  def activity_pub_taxonomy_actors
    @activity_pub_taxonomy_actors ||=
      begin
        if !@destroyed_post_activity_pub_taxonomy_actors.nil?
          return @destroyed_post_activity_pub_taxonomy_actors
        end
        return [] unless activity_pub_topic
        activity_pub_topic.activity_pub_taxonomies.map { |taxonomy| taxonomy.activity_pub_actor }
      end
  end

  def activity_pub_taxonomy_followers
    @activity_pub_taxonomy_followers ||=
      activity_pub_taxonomy_actors.reduce([]) do |result, actor|
        actor.followers.each { |follower| result << follower }
        result
      end
  end

  def activity_pub_url
    activity_pub_local? ? activity_pub_full_url : activity_pub_object&.url
  end

  def activity_pub_full_url
    "#{DiscourseActivityPub.base_url}#{self.url}"
  end

  def activity_pub_domain
    self.activity_pub_object&.domain
  end

  def activity_pub_full_topic
    @activity_pub_full_topic ||= activity_pub_topic&.activity_pub_full_topic
  end

  def activity_pub_first_post
    @activity_pub_first_post ||= !activity_pub_full_topic
  end

  def activity_pub_enabled
    return @activity_pub_enabled if !@activity_pub_enabled.nil?
    return false unless DiscourseActivityPub.enabled
    return false unless activity_pub_topic&.activity_pub_ready?
    return false if whisper?

    is_first_post? || activity_pub_full_topic
  end

  def activity_pub_perform_activity?
    return false if performing_activity_stop
    return false unless DiscourseActivityPub.publishing_enabled && activity_pub_enabled
    unless (
             is_first_post? || activity_pub_topic_scheduled? || activity_pub_topic_published? ||
               activity_pub_published?
           )
      return false
    end
    return false if self.activity_pub_deleted? && performing_activity.update?
    performing_activity&.composition?
  end

  def activity_pub_content
    return nil unless activity_pub_enabled

    (
      custom_fields["activity_pub_content"].presence ||
        DiscourseActivityPub::ContentParser.get_content(self)
    )
  end

  def activity_pub_published_at
    # We have to do this because sometimes we store multiple published_at timestamps
    # TODO: figure out what causes us to store multiples of this custom field
    Array(custom_fields["activity_pub_published_at"]).first
  end

  def activity_pub_actor
    return @activity_pub_actor if !@activity_pub_actor.nil?
    return nil unless activity_pub_enabled
    return nil unless activity_pub_topic.activity_pub_taxonomy

    if activity_pub_full_topic
      user.activity_pub_actor
    else
      activity_pub_topic.activity_pub_actor
    end
  end

  def activity_pub_update_custom_fields(args = {})
    if !activity_pub_enabled || (args.keys & self.class.activity_pub_custom_fields).empty?
      return nil
    end
    args.keys.each { |key| custom_fields["activity_pub_#{key}"] = args[key] }
    save_custom_fields(true)
    activity_pub_publish_state
  end

  def activity_pub_after_publish(args = {})
    activity_pub_update_custom_fields(args)
    activity_pub_topic&.activity_pub_publish_state if is_first_post?
  end

  def activity_pub_after_scheduled(args = {})
    activity_pub_update_custom_fields(args)
    activity_pub_topic&.activity_pub_publish_state if is_first_post?
  end

  def activity_pub_after_deliver(args = {})
    activity_pub_update_custom_fields(args)
    activity_pub_topic&.activity_pub_publish_state if is_first_post?
  end

  def activity_pub_updated_at
    custom_fields["activity_pub_updated_at"]
  end

  def activity_pub_visibility
    return @activity_pub_visibility if !@activity_pub_visibility.nil?
    if activity_pub_full_topic
      "public"
    else
      custom_fields["activity_pub_visibility"] ||
        activity_pub_topic&.activity_pub_taxonomy&.activity_pub_default_visibility
    end
  end

  def activity_pub_published?
    !!activity_pub_published_at
  end

  def activity_pub_deleted?
    !!activity_pub_deleted_at
  end

  def activity_pub_scheduled?
    !!activity_pub_scheduled_at
  end

  def activity_pub_delivered?
    !!activity_pub_delivered_at
  end

  def activity_pub_publish_state
    return false unless activity_pub_enabled
    return false unless activity_pub_topic

    model = {
      id: self.id,
      type: "post",
      post_number: self.post_number,
      topic_id: self.activity_pub_topic.id,
    }

    self.class.activity_pub_custom_fields.each do |field|
      model[field.to_sym] = self.send("activity_pub_#{field}")
    end

    group_ids = [::Group::AUTO_GROUPS[:staff]]
    if activity_pub_topic.activity_pub_taxonomy.is_a?(Category)
      group_ids.push(*activity_pub_topic.activity_pub_taxonomy.moderating_groups.pluck(:id))
    end

    ::MessageBus.publish("/activity-pub", { model: model }, { group_ids: group_ids })
  end

  def before_clear_all_activity_pub_objects
    return if self.destroyed?

    self.class.activity_pub_custom_field_names.each do |field_name|
      self.custom_fields[field_name] = nil
    end
    self.save_custom_fields(true)
  end

  def performing_activity_before_perform
    if !self.activity_pub_published? && performing_activity&.delete?
      self.clear_all_activity_pub_objects
      if is_first_post? && activity_pub_full_topic
        self.activity_pub_topic.posts.each { |post| post.clear_all_activity_pub_objects }
        self.activity_pub_topic.clear_all_activity_pub_objects
        topic&.activity_pub_publish_state
      end
      self.activity_pub_publish_state
      @performing_activity_stop = true
    end

    if !self.activity_pub_published? && performing_activity&.update?
      @performing_activity_object = activity_pub_object
      performing_activity_update_object
      @performing_activity_stop = true
    end

    if performing_activity&.create? && self.activity_pub_object&.ap&.tombstone?
      self.activity_pub_object.restore_tombstoned!
      if is_first_post? && activity_pub_full_topic
        self.topic.activity_pub_object&.restore_tombstoned!
      end
    end
  end

  def performing_activity_before_deliver
    if !self.destroyed? && !activity_pub_published? && !performing_activity.create?
      activity_pub_after_scheduled(scheduled_at: activity_pub_scheduled_at)
      @performing_activity_skip_delivery = true
    end
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

  def activity_pub_object_type
    self.activity_pub_object&.ap_type || self.activity_pub_default_object_type
  end

  def activity_pub_default_object_type
    self.activity_pub_topic&.activity_pub_taxonomy&.activity_pub_post_object_type ||
      DiscourseActivityPub::AP::Object::Note.type
  end

  def activity_pub_reply_to_object
    return if is_first_post?
    @activity_pub_reply_to_object ||=
      begin
        post =
          ::Post.find_by(
            "topic_id = :topic_id AND post_number = :post_number",
            topic_id: topic_id,
            post_number: reply_to_post_number || 1,
          )
        post&.activity_pub_object
      end
  end

  def activity_pub_local?
    activity_pub_enabled && (!activity_pub_object || activity_pub_object.local)
  end

  def activity_pub_remote?
    activity_pub_enabled && !activity_pub_local?
  end

  def activity_pub_topic_published?
    activity_pub_topic&.activity_pub_published?
  end

  def activity_pub_topic_scheduled?
    activity_pub_topic&.activity_pub_scheduled?
  end

  def activity_pub_collection
    activity_pub_topic.activity_pub_object
  end

  def activity_pub_visibility_on_create
    if is_first_post?
      activity_pub_topic&.activity_pub_taxonomy&.activity_pub_default_visibility
    else
      activity_pub_topic.first_post.activity_pub_visibility
    end
  end

  def activity_pub_publish!
    return false if activity_pub_published?

    content = DiscourseActivityPub::ContentParser.get_content(self)
    visibility =
      (
        if is_first_post?
          activity_pub_topic.activity_pub_taxonomy&.activity_pub_default_visibility
        else
          activity_pub_topic.first_post.activity_pub_visibility
        end
      )

    custom_fields["activity_pub_content"] = content
    custom_fields["activity_pub_visibility"] = visibility
    save_custom_fields(true)

    if topic.activity_pub_full_topic_enabled && !topic.activity_pub_object
      topic.create_activity_pub_collection!
    end

    perform_activity_pub_activity(:create)
  end

  def activity_pub_delete!
    return false unless activity_pub_local?
    perform_activity_pub_activity(:delete)
  end

  def activity_pub_deliver!
    return false if !activity_pub_published? || activity_pub_taxonomy_followers.blank?
    activity_pub_deliver_create
  end

  def activity_pub_schedule!
    if activity_pub_published? || activity_pub_scheduled? || activity_pub_taxonomy_followers.blank?
      return false
    end
    activity_pub_publish!
  end

  def activity_pub_unschedule!
    return false if activity_pub_published? || !activity_pub_scheduled?
    activity_pub_delete!
  end

  def activity_pub_name
    is_first_post? ? activity_pub_topic.activity_pub_name : nil
  end

  def activity_pub_topic_actor
    activity_pub_object.local? ? activity_pub_topic.activity_pub_actor : nil
  end

  def activity_pub_topic
    topic || activity_pub_topic_trashed
  end

  def activity_pub_topic_trashed
    @activity_pub_topic_trashed ||= ::Topic.with_deleted.find_by(id: self.topic_id)
  end

  def activity_pub_object_id
    activity_pub_object&.ap_id
  end

  def performing_activity_delivery_delay=(delay)
    @performing_activity_delivery_delay = delay
  end

  def performing_activity_delivery_delay
    return @performing_activity_delivery_delay if @performing_activity_delivery_delay.present?

    if !self.destroyed? && !activity_pub_topic_published?
      SiteSetting.activity_pub_delivery_delay_minutes.to_i
    else
      nil
    end
  end

  def activity_pub_attachments
    uploads
      .where(extension: FileHelper.supported_images)
      .map do |upload|
        DiscourseActivityPub::AP::Object::Image.new(
          json: {
            name: upload.original_filename,
            url: UrlHelper.absolute(upload.url),
            mediaType: MiniMime.lookup_by_extension(upload.extension).content_type,
          },
        )
      end
  end

  def cache_activity_pub_after_destroy
    @activity_pub_enabled = self.activity_pub_enabled
    @activity_pub_actor = self.activity_pub_actor
    @activity_pub_visibility = self.activity_pub_visibility
    @activity_pub_taxonomy_actors = self.activity_pub_taxonomy_actors
    @activity_pub_full_topic = self.activity_pub_full_topic
    @activity_pub_first_post = self.activity_pub_first_post
  end
end
