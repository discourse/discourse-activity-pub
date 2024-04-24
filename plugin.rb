# frozen_string_literal: true

# name: discourse-activity-pub
# about: ActivityPub plugin for Discourse
# version: 0.1.0
# authors: Angus McLeod
# meta_topic_id: 266794

register_asset "stylesheets/common/common.scss"
register_svg_icon "discourse-activity-pub"
register_svg_icon "fingerprint"
register_svg_icon "user-check"

add_admin_route "admin.discourse_activity_pub.label", "activityPub"

after_initialize do
  require_relative "lib/discourse_activity_pub/engine"
  require_relative "lib/discourse_activity_pub/json_ld"
  require_relative "lib/discourse_activity_pub/uri"
  require_relative "lib/discourse_activity_pub/request"
  require_relative "lib/discourse_activity_pub/webfinger"
  require_relative "lib/discourse_activity_pub/username_validator"
  require_relative "lib/discourse_activity_pub/username_suggester"
  require_relative "lib/discourse_activity_pub/content_parser"
  require_relative "lib/discourse_activity_pub/signature_parser"
  require_relative "lib/discourse_activity_pub/delivery_failure_tracker"
  require_relative "lib/discourse_activity_pub/actor_handler"
  require_relative "lib/discourse_activity_pub/post_handler"
  require_relative "lib/discourse_activity_pub/delivery_handler"
  require_relative "lib/discourse_activity_pub/follow_handler"
  require_relative "lib/discourse_activity_pub/bulk/process_result"
  require_relative "lib/discourse_activity_pub/bulk/process"
  require_relative "lib/discourse_activity_pub/bulk/publish_result"
  require_relative "lib/discourse_activity_pub/bulk/publish"
  require_relative "lib/discourse_activity_pub/auth"
  require_relative "lib/discourse_activity_pub/auth/app"
  require_relative "lib/discourse_activity_pub/auth/authorization"
  require_relative "lib/discourse_activity_pub/auth/discourse"
  require_relative "lib/discourse_activity_pub/auth/mastodon"
  require_relative "lib/discourse_activity_pub/webfinger/handle"
  require_relative "lib/discourse_activity_pub/activity_forwarder"
  require_relative "lib/discourse_activity_pub/logger"
  require_relative "lib/discourse_activity_pub/context_resolver"
  require_relative "lib/discourse_activity_pub/ap"
  require_relative "lib/discourse_activity_pub/ap/handlers"
  require_relative "lib/discourse_activity_pub/ap/object"
  require_relative "lib/discourse_activity_pub/ap/actor"
  require_relative "lib/discourse_activity_pub/ap/actor/group"
  require_relative "lib/discourse_activity_pub/ap/actor/person"
  require_relative "lib/discourse_activity_pub/ap/actor/application"
  require_relative "lib/discourse_activity_pub/ap/actor/service"
  require_relative "lib/discourse_activity_pub/ap/activity"
  require_relative "lib/discourse_activity_pub/ap/activity/follow"
  require_relative "lib/discourse_activity_pub/ap/activity/response"
  require_relative "lib/discourse_activity_pub/ap/activity/accept"
  require_relative "lib/discourse_activity_pub/ap/activity/announce"
  require_relative "lib/discourse_activity_pub/ap/activity/reject"
  require_relative "lib/discourse_activity_pub/ap/activity/compose"
  require_relative "lib/discourse_activity_pub/ap/activity/create"
  require_relative "lib/discourse_activity_pub/ap/activity/delete"
  require_relative "lib/discourse_activity_pub/ap/activity/update"
  require_relative "lib/discourse_activity_pub/ap/activity/undo"
  require_relative "lib/discourse_activity_pub/ap/activity/like"
  require_relative "lib/discourse_activity_pub/ap/object/note"
  require_relative "lib/discourse_activity_pub/ap/object/article"
  require_relative "lib/discourse_activity_pub/ap/collection"
  require_relative "lib/discourse_activity_pub/ap/collection/collection_page"
  require_relative "lib/discourse_activity_pub/ap/collection/ordered_collection_page"
  require_relative "lib/discourse_activity_pub/ap/collection/ordered_collection"
  require_relative "lib/discourse_activity_pub/admin"
  require_relative "app/models/concerns/discourse_activity_pub/ap/identifier_validations"
  require_relative "app/models/concerns/discourse_activity_pub/ap/object_validations"
  require_relative "app/models/concerns/discourse_activity_pub/ap/model_validations"
  require_relative "app/models/concerns/discourse_activity_pub/ap/model_callbacks"
  require_relative "app/models/concerns/discourse_activity_pub/ap/model_helpers"
  require_relative "app/models/concerns/discourse_activity_pub/webfinger_actor_attributes"
  require_relative "app/models/discourse_activity_pub_actor"
  require_relative "app/models/discourse_activity_pub_activity"
  require_relative "app/models/discourse_activity_pub_follow"
  require_relative "app/models/discourse_activity_pub_object"
  require_relative "app/models/discourse_activity_pub_collection"
  require_relative "app/jobs/discourse_activity_pub_process"
  require_relative "app/jobs/discourse_activity_pub_deliver"
  require_relative "app/controllers/concerns/discourse_activity_pub/domain_verification"
  require_relative "app/controllers/concerns/discourse_activity_pub/signature_verification"
  require_relative "app/controllers/concerns/discourse_activity_pub/enabled_verification"
  require_relative "app/controllers/discourse_activity_pub/ap/objects_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/actors_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/inboxes_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/outboxes_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/followers_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/activities_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/collections_controller"
  require_relative "app/controllers/discourse_activity_pub/ap/shared_inboxes_controller"
  require_relative "app/controllers/discourse_activity_pub/webfinger_controller"
  require_relative "app/controllers/discourse_activity_pub/webfinger/handle_controller"
  require_relative "app/controllers/discourse_activity_pub/auth_controller"
  require_relative "app/controllers/discourse_activity_pub/auth/authorization_controller"
  require_relative "app/controllers/discourse_activity_pub/admin/admin_controller"
  require_relative "app/controllers/discourse_activity_pub/admin/actor_controller"
  require_relative "app/controllers/discourse_activity_pub/post_controller"
  require_relative "app/controllers/discourse_activity_pub/actor_controller"
  require_relative "app/serializers/discourse_activity_pub/ap/object_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/response_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/accept_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/reject_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/follow_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/compose_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/create_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/delete_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/update_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/announce_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/like_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/activity/undo_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/actor_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/actor/application_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/actor/group_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/actor/person_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/object/note_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/object/article_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/collection_serializer"
  require_relative "app/serializers/discourse_activity_pub/ap/collection/ordered_collection_serializer"
  require_relative "app/serializers/discourse_activity_pub/webfinger_serializer"
  require_relative "app/serializers/discourse_activity_pub/basic_actor_serializer"
  require_relative "app/serializers/discourse_activity_pub/actor_serializer"
  require_relative "app/serializers/discourse_activity_pub/auth/authorization_serializer"
  require_relative "app/serializers/discourse_activity_pub/admin/actor_serializer"
  require_relative "config/routes"
  require_relative "extensions/discourse_activity_pub_guardian_extension"

  # DiscourseActivityPub.enabled is the single source of truth for whether
  # ActivityPub is enabled on the site level
  add_to_serializer(:site, :activity_pub_enabled) { DiscourseActivityPub.enabled }
  add_to_serializer(:site, :activity_pub_publishing_enabled) do
    DiscourseActivityPub.publishing_enabled
  end
  add_to_serializer(:site, :activity_pub_host) { DiscourseActivityPub.host }

  DiscourseActivityPubActor::ACTIVE_MODELS.each do |model_type|
    model_type.constantize.has_one :activity_pub_actor,
                                   class_name: "DiscourseActivityPubActor",
                                   as: :model,
                                   dependent: :destroy
    model_type.constantize.has_many :activity_pub_followers,
                                    through: :activity_pub_actor,
                                    source: :followers,
                                    class_name: "DiscourseActivityPubActor"
    model_type.constantize.has_many :activity_pub_follows,
                                    through: :activity_pub_actor,
                                    source: :follows,
                                    class_name: "DiscourseActivityPubActor"

    class_name = model_type.downcase.to_sym

    add_to_class(class_name, :activity_pub_url) { "#{DiscourseActivityPub.base_url}#{self.url}" }
    add_to_class(class_name, :activity_pub_icon_url) { DiscourseActivityPub.icon_url }
    add_to_class(class_name, :activity_pub_enabled) do
      DiscourseActivityPub.enabled && !!activity_pub_actor&.enabled
    end
    add_to_class(class_name, :activity_pub_allowed?) do
      case model_type
      when "Category"
        !self.read_restricted
      when "Tag"
        true
      end
    end
    add_to_class(class_name, :activity_pub_ready?) { activity_pub_enabled && activity_pub_allowed? }
    add_to_class(class_name, :activity_pub_username) { activity_pub_actor.username }
    add_to_class(class_name, :activity_pub_name) { activity_pub_actor.name }
    add_to_class(class_name, :activity_pub_publish_state) do
      message = {
        model: {
          id: self.id,
          type: class_name.to_s,
          ready: activity_pub_ready?,
          enabled: activity_pub_enabled,
        },
      }
      MessageBus.publish("/activity-pub", message)
    end
    add_to_class(class_name, :activity_pub_default_visibility) do
      if activity_pub_full_topic
        "public"
      else
        activity_pub_actor.default_visibility || DiscourseActivityPubActivity.default_visibility
      end
    end
    add_to_class(class_name, :activity_pub_post_object_type) do
      activity_pub_actor&.post_object_type
    end
    add_to_class(class_name, :activity_pub_default_object_type) do
      DiscourseActivityPub::AP::Actor::Group.type
    end
    add_to_class(class_name, :activity_pub_publication_type) do
      activity_pub_actor&.publication_type || "first_post"
    end
    add_to_class(class_name, :activity_pub_first_post) do
      activity_pub_publication_type === "first_post"
    end
    add_to_class(class_name, :activity_pub_full_topic) do
      activity_pub_publication_type === "full_topic"
    end
    add_to_class(class_name, :activity_pub_default_object_type) do
      DiscourseActivityPub::AP::Actor::Group.type
    end
    add_to_class(class_name, :activity_pub_follower_count) { activity_pub_followers.count }
  end

  on(:site_setting_changed) do |name, old_val, new_val|
    if %i[activity_pub_enabled login_required].include?(name)
      DiscourseActivityPubActor.active.each { |actor| actor.model.activity_pub_publish_state }
    end
  end

  add_to_serializer(:site, :activity_pub_actors) do
    actors = { category: [], tag: [] }
    DiscourseActivityPubActor.active.each do |actor|
      actors[actor.model_type.downcase.to_sym] << DiscourseActivityPub::BasicActorSerializer.new(
        actor,
        root: false,
      ).as_json
    end
    actors.as_json
  end

  Topic.has_one :activity_pub_object, class_name: "DiscourseActivityPubCollection", as: :model
  Topic.include DiscourseActivityPub::AP::ModelHelpers

  add_to_class(:topic, :activity_pub_taxonomies) do
    [*tags, category].select { |t| t&.activity_pub_actor.present? }
  end
  add_to_class(:topic, :activity_pub_taxonomy) { activity_pub_taxonomies.first }
  add_to_class(:topic, :activity_pub_enabled) do
    regular? && DiscourseActivityPub.enabled && activity_pub_taxonomy&.activity_pub_ready?
  end
  add_to_class(:topic, :activity_pub_ready?) do
    activity_pub_enabled &&
      (activity_pub_first_post || (activity_pub_full_topic && activity_pub_object))
  end
  add_to_class(:topic, :activity_pub_full_url) do
    "#{DiscourseActivityPub.base_url}#{self.relative_url}"
  end
  add_to_class(:topic, :activity_pub_published?) do
    return false unless activity_pub_enabled

    first_post = posts.with_deleted.find_by(post_number: 1)
    first_post&.activity_pub_published?
  end
  add_to_class(:topic, :activity_pub_first_post) { activity_pub_taxonomy&.activity_pub_first_post }
  add_to_class(:topic, :activity_pub_full_topic) { activity_pub_taxonomy&.activity_pub_full_topic }
  add_to_class(:topic, :activity_pub_full_topic_enabled) do
    activity_pub_enabled && activity_pub_full_topic
  end
  add_to_class(:topic, :create_activity_pub_collection!) do
    create_activity_pub_object!(
      local: true,
      ap_type: DiscourseActivityPub::AP::Collection::OrderedCollection.type,
      name: activity_pub_name,
    )
  end
  add_to_class(:topic, :activity_pub_activities_collection) do
    activity_pub_object.activities_collection
  end
  add_to_class(:topic, :activity_pub_objects_collection) { activity_pub_object.objects_collection }
  add_to_class(:topic, :activity_pub_actor) { activity_pub_taxonomy&.activity_pub_actor }
  add_to_class(:topic, :activity_pub_name) { title }
  add_to_class(:topic, :activity_pub_local?) do
    !first_post&.activity_pub_object || first_post.activity_pub_object.local
  end
  add_to_class(:topic, :activity_pub_remote?) { !activity_pub_local? }
  Post.has_one :activity_pub_object, class_name: "DiscourseActivityPubObject", as: :model

  Post.include DiscourseActivityPub::AP::ModelCallbacks
  Post.include DiscourseActivityPub::AP::ModelHelpers
  Guardian.prepend DiscourseActivityPubGuardianExtension

  activity_pub_post_custom_fields = %i[scheduled_at published_at deleted_at updated_at visibility]
  activity_pub_post_custom_field_names =
    activity_pub_post_custom_fields.map { |field_name| "activity_pub_#{field_name}" }
  activity_pub_post_custom_field_names.each do |field_name|
    register_post_custom_field_type(field_name, :string)
  end

  add_permitted_post_create_param(:activity_pub_visibility)

  add_to_class(:post, :activity_pub_url) do
    activity_pub_local? ? activity_pub_full_url : activity_pub_object&.url
  end
  add_to_class(:post, :activity_pub_full_url) { "#{DiscourseActivityPub.base_url}#{self.url}" }
  add_to_class(:post, :activity_pub_domain) { self.activity_pub_object&.domain }
  add_to_class(:post, :activity_pub_full_topic) do
    return @destroyed_post_activity_pub_full_topic if !@destroyed_post_activity_pub_full_topic.nil?
    activity_pub_topic&.activity_pub_full_topic
  end
  add_to_class(:post, :activity_pub_first_post) do
    return @destroyed_post_activity_pub_first_post if !@destroyed_post_activity_pub_first_post.nil?
    !activity_pub_full_topic
  end
  add_to_class(:post, :activity_pub_enabled) do
    return @destroyed_post_activity_pub_enabled if !@destroyed_post_activity_pub_enabled.nil?
    return false unless DiscourseActivityPub.enabled
    return false unless activity_pub_topic&.activity_pub_ready?

    is_first_post? || activity_pub_full_topic
  end
  add_to_class(:post, :activity_pub_content) do
    return nil unless activity_pub_enabled

    if custom_fields["activity_pub_content"].present?
      custom_fields["activity_pub_content"]
    else
      DiscourseActivityPub::ContentParser.get_content(self)
    end
  end
  add_to_class(:post, :activity_pub_actor) do
    return @destroyed_post_activity_pub_actor if !@destroyed_post_activity_pub_actor.nil?
    return nil unless activity_pub_enabled
    return nil unless activity_pub_topic.activity_pub_taxonomy

    if activity_pub_full_topic
      user.activity_pub_actor
    else
      activity_pub_topic.activity_pub_actor
    end
  end
  add_to_class(:post, :activity_pub_update_custom_fields) do |args = {}|
    return nil if !activity_pub_enabled || (args.keys & activity_pub_post_custom_fields).empty?
    args.keys.each { |key| custom_fields["activity_pub_#{key}"] = args[key] }
    save_custom_fields(true)
    activity_pub_publish_state
  end
  add_to_class(:post, :activity_pub_after_publish) do |args = {}|
    activity_pub_update_custom_fields(args)
  end
  add_to_class(:post, :activity_pub_after_scheduled) do |args = {}|
    activity_pub_update_custom_fields(args)
  end
  activity_pub_post_custom_field_names.each do |field_name|
    add_to_class(:post, field_name.to_sym) { custom_fields[field_name] }
  end
  add_to_class(:post, :activity_pub_updated_at) { custom_fields["activity_pub_updated_at"] }
  add_to_class(:post, :activity_pub_visibility) do
    return @destroyed_post_activity_pub_visibility if !@destroyed_post_activity_pub_visibility.nil?
    if activity_pub_full_topic
      "public"
    else
      custom_fields["activity_pub_visibility"] ||
        activity_pub_topic.activity_pub_taxonomy&.activity_pub_default_visibility
    end
  end
  add_to_class(:post, :activity_pub_published?) { !!activity_pub_published_at }
  add_to_class(:post, :activity_pub_deleted?) { !!activity_pub_deleted_at }
  add_to_class(:post, :activity_pub_scheduled?) { !!activity_pub_scheduled_at }
  add_to_class(:post, :activity_pub_publish_state) do
    return false unless activity_pub_enabled
    return false unless activity_pub_topic

    model = { id: self.id, type: "post" }

    activity_pub_post_custom_fields.each do |field|
      model[field.to_sym] = self.send("activity_pub_#{field}")
    end

    group_ids = [Group::AUTO_GROUPS[:staff]]
    if activity_pub_topic.activity_pub_taxonomy.is_a?(Category)
      group_ids.push(*activity_pub_topic.activity_pub_taxonomy.moderating_groups.pluck(:id))
    end

    MessageBus.publish("/activity-pub", { model: model }, { group_ids: group_ids })
  end
  add_to_class(:post, :before_clear_all_activity_pub_objects) do
    return if self.destroyed?

    activity_pub_post_custom_field_names.each { |field_name| self.custom_fields[field_name] = nil }
    self.save_custom_fields(true)
  end
  add_to_class(:post, :before_perform_activity_pub_activity) do |performing_activity|
    return performing_activity if self.activity_pub_published?

    if performing_activity.delete?
      self.clear_all_activity_pub_objects
      if is_first_post? && activity_pub_full_topic
        self.activity_pub_topic.clear_all_activity_pub_objects
      end
      self.activity_pub_publish_state
      return nil
    end

    performing_activity
  end
  add_to_class(:post, :activity_pub_object_type) do
    self.activity_pub_object&.ap_type || self.activity_pub_default_object_type
  end
  add_to_class(:post, :activity_pub_default_object_type) do
    self.activity_pub_topic&.activity_pub_taxonomy&.activity_pub_post_object_type ||
      DiscourseActivityPub::AP::Object::Note.type
  end
  add_to_class(:post, :activity_pub_reply_to_object) do
    return if is_first_post?
    @activity_pub_reply_to_object ||=
      begin
        post =
          Post.find_by(
            "topic_id = :topic_id AND post_number = :post_number",
            topic_id: topic_id,
            post_number: reply_to_post_number || 1,
          )
        post&.activity_pub_object
      end
  end
  add_to_class(:post, :activity_pub_local?) do
    activity_pub_enabled && (!activity_pub_object || activity_pub_object.local)
  end
  add_to_class(:post, :activity_pub_remote?) { activity_pub_enabled && !activity_pub_local? }
  add_to_class(:post, :activity_pub_topic_published?) { activity_pub_topic.activity_pub_published? }
  add_to_class(:post, :activity_pub_is_first_post?) { is_first_post? }
  add_to_class(:post, :activity_pub_first_post_scheduled_at) do
    activity_pub_topic.first_post&.activity_pub_scheduled_at
  end
  add_to_class(:post, :activity_pub_group_actors) do
    if !@destroyed_post_activity_pub_group_actors.nil?
      return @destroyed_post_activity_pub_group_actors
    end
    activity_pub_topic.activity_pub_taxonomies.map { |t| t.activity_pub_actor }
  end
  add_to_class(:post, :activity_pub_collection) { activity_pub_topic.activity_pub_object }
  add_to_class(:post, :activity_pub_valid_activity?) do |activity, target_activity|
    activity&.composition?
  end
  add_to_class(:post, :activity_pub_visibility_on_create) do
    if is_first_post?
      activity_pub_topic&.category&.activity_pub_default_visibility
    else
      activity_pub_topic.first_post.activity_pub_visibility
    end
  end
  add_to_class(:post, :activity_pub_publish?) { !whisper? }
  add_to_class(:post, :activity_pub_publish!) do
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

    perform_activity_pub_activity(:create)
  end
  add_to_class(:post, :activity_pub_delete!) do
    return false unless activity_pub_local?
    perform_activity_pub_activity(:delete)
  end
  add_to_class(:post, :activity_pub_schedule!) do
    return false if activity_pub_published? || activity_pub_scheduled?
    activity_pub_publish!
  end
  add_to_class(:post, :activity_pub_unschedule!) do
    return false if activity_pub_published? || !activity_pub_scheduled?
    activity_pub_delete!
  end
  add_to_class(:post, :activity_pub_name) do
    is_first_post? ? activity_pub_topic.activity_pub_name : nil
  end
  add_to_class(:post, :activity_pub_topic_actor) do
    activity_pub_object.local? ? activity_pub_topic.activity_pub_actor : nil
  end
  add_to_class(:post, :activity_pub_topic) { topic || activity_pub_topic_trashed }
  add_to_class(:post, :activity_pub_topic_trashed) do
    @activity_pub_topic_trashed ||= Topic.with_deleted.find_by(id: self.topic_id)
  end
  add_to_class(:post, :activity_pub_object_id) { activity_pub_local? && activity_pub_object&.ap_id }

  add_model_callback(:post, :after_destroy) do
    # We need these to create a Delete activity when the post is actually destroyed
    @destroyed_post_activity_pub_enabled = self.activity_pub_enabled
    @destroyed_post_activity_pub_actor = self.activity_pub_actor
    @destroyed_post_activity_pub_visibility = self.activity_pub_visibility
    @destroyed_post_activity_pub_group_actors = self.activity_pub_group_actors
    @destroyed_post_activity_pub_full_topic = self.activity_pub_full_topic
    @destroyed_post_activity_pub_first_post = self.activity_pub_first_post
  end

  add_to_serializer(:post, :activity_pub_enabled) { object.activity_pub_enabled }
  activity_pub_post_custom_field_names.each do |field_name|
    add_to_serializer(
      :post,
      field_name.to_sym,
      include_condition: -> { object.activity_pub_enabled },
    ) { object.send(field_name) }
  end
  add_to_serializer(
    :post,
    :activity_pub_local,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_local? }
  add_to_serializer(
    :post,
    :activity_pub_url,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_url }
  add_to_serializer(
    :post,
    :activity_pub_domain,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_domain }
  add_to_serializer(
    :post,
    :activity_pub_object_type,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_object_type }
  add_to_serializer(
    :post,
    :activity_pub_first_post,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_first_post }
  add_to_serializer(
    :post,
    :activity_pub_is_first_post,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_is_first_post? }
  add_to_serializer(
    :post,
    :activity_pub_object_id,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_object_id }

  TopicView.on_preload do |topic_view|
    if topic_view.topic.activity_pub_enabled
      Post.preload_custom_fields(topic_view.posts, activity_pub_post_custom_field_names)
      ActiveRecord::Associations::Preloader.new(
        records: topic_view.posts,
        associations: [:activity_pub_object],
      ).call
    end
  end

  PostAction.include DiscourseActivityPub::AP::ModelCallbacks

  add_to_class(:post_action, :activity_pub_enabled) { post.activity_pub_enabled }
  add_to_class(:post_action, :activity_pub_publish?) { true }
  add_to_class(:post_action, :activity_pub_deleted?) { nil }
  add_to_class(:post_action, :activity_pub_published?) { !!post.activity_pub_published_at }
  add_to_class(:post_action, :activity_pub_visibility) { "public" }
  add_to_class(:post_action, :activity_pub_actor) { user.activity_pub_actor }
  add_to_class(:post_action, :activity_pub_group_actors) { post.activity_pub_group_actors }
  add_to_class(:post_action, :activity_pub_object) { post.activity_pub_object }
  add_to_class(:post_action, :activity_pub_full_topic) { post.activity_pub_full_topic }
  add_to_class(:post_action, :activity_pub_first_post) { post.activity_pub_first_post }
  add_to_class(:post_action, :activity_pub_topic_published?) { post.activity_pub_topic_published? }
  add_to_class(:post_action, :activity_pub_is_first_post?) { false }
  add_to_class(:post_action, :activity_pub_collection) { post.activity_pub_collection }
  add_to_class(:post_action, :activity_pub_valid_activity?) do |activity, target_activity|
    return false unless activity_pub_full_topic
    activity && (activity.like? || activity.undo? && target_activity.like?)
  end

  User.has_one :activity_pub_actor, class_name: "DiscourseActivityPubActor", as: :model

  # TODO: This should just be part of discourse/discourse.
  User.skip_callback :create, :after, :create_email_token, if: -> { self.skip_email_validation }

  add_model_callback(:user, :before_validation) do
    if self.instance_variable_get(:@skip_email_validation).nil? && self.activity_pub_actor&.remote?
      self.instance_variable_set(:@skip_email_validation, true)
    end
  end
  add_model_callback(:user, :before_destroy) do
    DiscourseActivityPubActor.where(model_id: self.id, model_type: "User").destroy_all
  end

  add_to_class(:user, :activity_pub_enabled) { DiscourseActivityPub.enabled }
  add_to_class(:user, :activity_pub_ready?) { true }
  add_to_class(:user, :activity_pub_allowed?) { true }
  add_to_class(:user, :activity_pub_url) { full_url }
  add_to_class(:user, :activity_pub_icon_url) { avatar_template_url.gsub("{size}", "96") }
  add_to_class(:user, :activity_pub_save_access_token) do |domain, access_token|
    return unless domain && access_token
    tokens = activity_pub_access_tokens
    tokens[domain] = access_token
    custom_fields["activity_pub_access_tokens"] = tokens
    save_custom_fields(true)
  end
  add_to_class(:user, :activity_pub_save_actor_id) do |domain, actor_id|
    return unless domain && actor_id
    actor_ids = activity_pub_actor_ids
    actor_ids[actor_id] = domain
    custom_fields["activity_pub_actor_ids"] = actor_ids
    save_custom_fields(true)
  end
  add_to_class(:user, :activity_pub_remove_actor_id) do |actor_id|
    return unless actor_id
    actor_ids = activity_pub_actor_ids
    return if actor_ids[actor_id].blank?
    actor_ids.delete(actor_id)
    custom_fields["activity_pub_actor_ids"] = actor_ids
    save_custom_fields(true)
  end
  add_to_class(:user, :activity_pub_access_tokens) do
    if custom_fields["activity_pub_access_tokens"]
      JSON.parse(custom_fields["activity_pub_access_tokens"])
    else
      {}
    end
  end
  add_to_class(:user, :activity_pub_actor_ids) do
    if custom_fields["activity_pub_actor_ids"]
      JSON.parse(custom_fields["activity_pub_actor_ids"])
    else
      {}
    end
  end
  add_to_class(:user, :activity_pub_authorizations) do
    tokens = activity_pub_access_tokens
    activity_pub_actor_ids.map do |actor_id, domain|
      DiscourseActivityPub::Auth::Authorization.new(
        { actor_id: actor_id, domain: domain, access_token: tokens[domain] },
      )
    end
  end
  add_to_class(:user, :activity_pub_shared_inbox) { DiscourseActivityPub.users_shared_inbox }
  add_to_class(:user, :activity_pub_username) { username }
  add_to_class(:user, :activity_pub_name) { name }

  add_to_serializer(
    :user,
    :activity_pub_authorizations,
    include_condition: -> { DiscourseActivityPub.enabled },
  ) do
    object.activity_pub_authorizations.map do |authorization|
      DiscourseActivityPub::Auth::AuthorizationSerializer.new(authorization, root: false).as_json
    end
  end

  # TODO (future): discourse/discourse needs to cook earlier for validators.
  # See also discourse/discourse/plugins/poll/lib/poll.rb.
  on(:before_edit_post) do |post|
    if post.activity_pub_local?
      post.custom_fields["activity_pub_content"] = DiscourseActivityPub::ContentParser.get_content(
        post,
      )
    end
  end
  on(:post_edited) do |post, topic_changed, post_revisor|
    if post.activity_pub_full_topic && post_revisor.topic_title_changed?
      post.topic.activity_pub_object.name = post.topic.activity_pub_name
      post.topic.activity_pub_object.save!
    end
    opts = post_revisor.instance_variable_get("@opts")
    post.perform_activity_pub_activity(:update) if !opts[:deleting_post] && post.activity_pub_local?
  end
  on(:post_created) do |post, post_opts, user|
    # TODO (future): PR discourse/discourse to add a better context flag for different post_created scenarios.
    # Currently we're using skip_validations as an inverse flag for a "normal" post creation scenario.
    post.activity_pub_publish! if !post_opts[:skip_validations] && post.activity_pub_enabled
  end
  on(:post_destroyed) { |post, opts, user| post.activity_pub_delete! }
  on(:post_recovered) do |post, opts, user|
    post.perform_activity_pub_activity(:create) if post.activity_pub_local?
  end
  on(:topic_created) do |topic, opts, user|
    if topic.activity_pub_enabled && topic.activity_pub_full_topic
      topic.create_activity_pub_collection!
    end
  end
  on(:first_post_moved) do |new_post, old_post|
    topic = new_post.topic

    if topic.activity_pub_full_topic_enabled && !topic.activity_pub_object
      topic.create_activity_pub_collection!
    end

    note = old_post.activity_pub_object
    if note
      note.model_id = new_post.id
      note.collection_id =
        topic.activity_pub_full_topic_enabled ? topic.activity_pub_object.id : nil
      note.save!
    end
  end
  on(:post_moved) do |new_post, original_topic_id|
    if !new_post.is_first_post?
      topic = new_post.topic

      if topic.activity_pub_full_topic_enabled && !topic.activity_pub_object
        topic.create_activity_pub_collection!
      end

      note = new_post.activity_pub_object
      if note
        note.collection_id =
          topic.activity_pub_full_topic_enabled ? topic.activity_pub_object.id : nil
        note.save!
      end
    end
  end
  on(:like_created) do |post_action, post_action_creator|
    reason = post_action_creator.instance_variable_get("@reason")

    if post_action.activity_pub_enabled && post_action.activity_pub_full_topic &&
         reason != :activity_pub
      post_action.perform_activity_pub_activity(:like)
    end
  end
  on(:like_destroyed) do |post_action, post_action_destroyer|
    reason = post_action_destroyer.instance_variable_get("@reason")

    if post_action.activity_pub_enabled && post_action.activity_pub_full_topic &&
         reason != :activity_pub && post_action.user.activity_pub_actor.present?
      post_action.perform_activity_pub_activity(:undo, :like)
    end
  end
  on(:merging_users) do |source_user, target_user|
    if source_user.reload.activity_pub_actor&.remote?
      DiscourseActivityPubActor.where(id: source_user.activity_pub_actor.id).update_all(
        model_id: nil,
        model_type: nil,
      )
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:activity, :validate) do |activity|
    if DiscourseActivityPubActivity.exists?(ap_id: activity.json[:id])
      raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
            I18n.t("discourse_activity_pub.process.warning.activity_already_processed")
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:create, :validate) do |activity|
    context_resolver = DiscourseActivityPub::ContextResolver.new(activity.object.stored)
    context_resolver.perform
    unless context_resolver.success?
      raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
            context_resolver.errors.full_messages.join(", ")
    end

    reply_to_post = activity.object.stored.reload.in_reply_to_post

    if reply_to_post
      if reply_to_post.trashed?
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.cannot_reply_to_deleted_post")
      end
      unless reply_to_post.activity_pub_full_topic
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.full_topic_not_enabled")
      end
    else
      delivered_to_actors = []

      activity.delivered_to.each do |delivered_to_id|
        actor =
          DiscourseActivityPubActor.find_by(
            ap_id: delivered_to_id,
            local: true,
            ap_type: DiscourseActivityPub::AP::Actor::Group.type,
            model_type: DiscourseActivityPubActor::ACTIVE_MODELS,
          )
        delivered_to_actors << actor if actor
      end

      if delivered_to_actors.blank?
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.actor_does_not_accept_new_topics")
      end

      unless delivered_to_actors.any? { |actor|
               actor.following?(activity.actor.stored) ||
                 actor.following?(activity.parent&.actor&.stored)
             }
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t(
                "discourse_activity_pub.process.warning.only_followed_actors_create_new_topics",
              )
      end

      delivered_to_model = delivered_to_actors.first.model

      if !delivered_to_model.activity_pub_ready?
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.object_not_ready")
      end

      if delivered_to_model.is_a?(Category)
        activity.cache["delivered_to_category_id"] = delivered_to_model.id
      end
      activity.cache["delivered_to_tag_id"] = delivered_to_model.id if delivered_to_model.is_a?(Tag)
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:delete, :validate) do |activity|
    DiscourseActivityPub::PostHandler.ensure_activity_has_post(activity)
  end

  DiscourseActivityPub::AP::Activity.add_handler(:update, :validate) do |activity|
    DiscourseActivityPub::PostHandler.ensure_activity_has_post(activity)
  end

  DiscourseActivityPub::AP::Activity.add_handler(:like, :validate) do |activity|
    DiscourseActivityPub::PostHandler.ensure_activity_has_post(activity)
  end

  DiscourseActivityPub::AP::Activity.add_handler(:announce, :validate) do |activity|
    unless DiscourseActivityPub::JsonLd.publicly_addressed?(activity.json)
      raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
            I18n.t("discourse_activity_pub.process.warning.announce_not_publicly_addressed")
    end

    if activity.object.object?
      DiscourseActivityPub::AP::Activity.apply_handlers(activity, :create, :validate)
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:create, :perform) do |activity|
    user =
      DiscourseActivityPub::ActorHandler.update_or_create_user(activity.object.stored.attributed_to)

    unless user
      raise DiscourseActivityPub::AP::Handlers::Error::Perform,
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_create_user",
              actor_id: activity.object.stored.attributed_to&.ap_id,
            )
    end

    post =
      DiscourseActivityPub::PostHandler.create(
        user,
        activity.object.stored,
        category_id: activity.cache["delivered_to_category_id"],
        tag_id: activity.cache["delivered_to_tag_id"],
      )

    unless post
      raise DiscourseActivityPub::AP::Handlers::Error::Perform,
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_create_post",
              object_id: activity.object.id,
            )
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:delete, :perform) do |activity|
    post = activity.object.stored.model
    PostDestroyer.new(post.user, post, force_destroy: true).destroy
    activity.object.stored.destroy!
  end

  DiscourseActivityPub::AP::Activity.add_handler(:update, :perform) do |activity|
    post = activity.object.stored.model
    revisor = PostRevisor.new(post)
    revisor.revise!(post.user, { raw: activity.object.content })
  end

  DiscourseActivityPub::AP::Activity.add_handler(:like, :perform) do |activity|
    user = DiscourseActivityPub::ActorHandler.update_or_create_user(activity.actor.stored)

    unless user
      raise DiscourseActivityPub::AP::Handlers::Error::Perform,
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_create_user",
              actor_id: activity.actor.id,
            )
    end

    post = activity.object.stored.model

    if user && post
      PostActionCreator.new(
        user,
        post,
        PostActionType::LIKE_POST_ACTION_ID,
        reason: :activity_pub,
      ).perform
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:undo, :perform) do |activity|
    case activity.object.type
    when DiscourseActivityPub::AP::Activity::Follow.type
      DiscourseActivityPubFollow.where(
        follower_id: activity.actor.stored.id,
        followed_id: activity.object.object.stored.id,
      ).destroy_all
    when DiscourseActivityPub::AP::Activity::Like.type
      user = DiscourseActivityPub::ActorHandler.update_or_create_user(activity.actor.stored)
      post = activity.object.object.stored.model
      PostActionDestroyer.destroy(user, post, :like, reason: :activity_pub) if user && post
    else
      false
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:reject, :perform) do |activity|
    case activity.object.type
    when DiscourseActivityPub::AP::Activity::Follow.type
      DiscourseActivityPubFollow.where(
        follower_id: activity.object.actor.stored.id,
        followed_id: activity.actor.stored.id,
      ).destroy_all
    else
      false
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:announce, :perform) do |activity|
    DiscourseActivityPub::AP::Activity.apply_handlers(activity, :create, :perform)
  end

  DiscourseActivityPub::AP::Activity.add_handler(:follow, :respond_to) do |activity|
    response = DiscourseActivityPub::AP::Activity::Response.new
    if activity.stored&.errors.present?
      response.reject(message: activity.stored.errors.full_messages.join(", "))
    end
    if activity.actor.stored.following?(activity.object.stored)
      response.reject(key: "actor_already_following")
    end

    begin
      response.stored =
        DiscourseActivityPubActivity.create!(
          local: true,
          ap_type: response.type,
          actor_id: activity.object.stored.id,
          object_id: activity.stored&.id,
          object_type: "DiscourseActivityPubActivity",
          summary: response.summary,
        )

      if response.accepted?
        DiscourseActivityPubFollow.create!(
          follower_id: activity.actor.stored.id,
          followed_id: activity.object.stored.id,
        )
      end
    rescue ActiveRecord::RecordInvalid => error
      DiscourseActivityPub::Logger.object_store_error(response, error)
      raise DiscourseActivityPub::AP::Handlers::Error::RespondTo,
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_respond_to_follow",
              activity_id: activity.json[:id],
            )
    end

    DiscourseActivityPub::DeliveryHandler.perform(
      actor: activity.object.stored,
      object: response.stored,
      recipient_ids: activity.object.stored.followers.map(&:id),
    )
  end

  DiscourseActivityPub::AP::Activity.add_handler(:accept, :perform) do |activity|
    case activity.object.type
    when DiscourseActivityPub::AP::Activity::Follow.type
      DiscourseActivityPubFollow.create!(
        follower_id: activity.object.actor.stored.id,
        followed_id: activity.actor.stored.id,
      )
      message = { model: { id: activity.object.actor.stored.model.id, type: "category" } }
      MessageBus.publish("/activity-pub", message)
    else
      false
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:activity, :store) do |activity|
    public = DiscourseActivityPub::JsonLd.publicly_addressed?(activity.json)
    visibility = public ? :public : :private

    begin
      activity.stored =
        DiscourseActivityPubActivity.create!(
          ap_id: activity.json[:id],
          ap_type: activity.type,
          actor_id: activity.actor.stored.id,
          object_id: activity.object.stored.id,
          object_type: activity.object.stored.class.name,
          visibility: DiscourseActivityPubActivity.visibilities[visibility],
          published_at: activity.json[:published],
        )
    rescue ActiveRecord::RecordInvalid => error
      DiscourseActivityPub::Logger.object_store_error(activity, error)
      raise DiscourseActivityPub::AP::Handlers::Error::Store,
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_save_activity",
              activity_id: activity.json[:id],
            )
    end

    activity.cache["new"] = true # existing records will raise an error
  end

  DiscourseActivityPub::AP::Object.add_handler(:object, :resolve) do |object, opts|
    activity = opts[:parent]

    stored =
      if activity&.composition? || (object.object? && activity&.announce?)
        DiscourseActivityPubObject.find_by(ap_id: object.json[:id])
      elsif activity&.like?
        DiscourseActivityPubObject.find_by(ap_id: object.json[:id])
      elsif activity&.follow?
        DiscourseActivityPubActor.find_by(ap_id: object.json[:id])
      elsif activity&.undo?
        DiscourseActivityPubActivity.find_by(ap_id: object.json[:id])
      elsif activity&.reject?
        DiscourseActivityPubActivity.find_by(ap_id: object.json[:id])
      elsif activity&.response?
        DiscourseActivityPubActivity.find_by(ap_id: object.json[:id])
      end

    object.stored = stored if stored
  end

  DiscourseActivityPub::AP::Object.add_handler(:object, :store) do |object, opts|
    activity = opts[:parent]

    if activity&.composition? || (object.object? && activity&.announce?)
      DiscourseActivityPubObject.transaction do
        if object.stored && activity.update?
          object.stored.content = object.json[:content] if object.json[:content].present?
          object.stored.name = object.json[:name] if object.json[:name].present?
          object.stored.audience = object.json[:audience] if object.json[:audience].present?
          object.stored.context = object.json[:context] if object.json[:context].present?
          object.stored.target = object.json[:target] if object.json[:target].present?
        elsif !object.stored && (activity&.create? || activity&.announce?)
          params = {
            local: false,
            ap_id: object.json[:id],
            ap_type: object.json[:type],
            content: object.json[:content],
            published_at: object.json[:published],
            domain: DiscourseActivityPub::JsonLd.domain_from_id(object.json[:id]),
            name: object.json[:name],
          }
          params[:audience] = object.json[:audience] if object.json[:audience]
          params[:context] = object.json[:context] if object.json[:context]
          params[:target] = object.json[:target] if object.json[:target]
          params[:reply_to_id] = object.json[:inReplyTo] if object.json[:inReplyTo]
          params[:url] = object.json[:url] if object.json[:url]
          params[:attributed_to_id] = object.attributed_to.id if object.attributed_to.present?
          object.stored = DiscourseActivityPubObject.new(params)
        end

        if object.stored && (object.stored.new_record? || object.stored.changed?)
          begin
            object.stored.save!
          rescue ActiveRecord::RecordInvalid => error
            DiscourseActivityPub::Logger.object_store_error(object, error)
            raise DiscourseActivityPub::AP::Handlers::Error::Store,
                  I18n.t(
                    "discourse_activity_pub.process.error.failed_to_save_object",
                    object_id: object.json[:id],
                  )
          end
        end
      end
    end
  end

  DiscourseActivityPub::AP::Object.add_handler(:actor, :store) do |actor|
    actor.stored = DiscourseActivityPubActor.find_by(ap_id: actor.json[:id])

    DiscourseActivityPubActor.transaction do
      if !actor.stored
        actor.stored =
          DiscourseActivityPubActor.new(
            ap_id: actor.json[:id],
            ap_type: actor.json[:type],
            domain: DiscourseActivityPub::JsonLd.domain_from_id(actor.json[:id]),
            username: actor.json[:preferredUsername],
            inbox: actor.json[:inbox],
            outbox: actor.json[:outbox],
            name: actor.json[:name],
            icon_url: DiscourseActivityPub::JsonLd.resolve_icon_url(actor.json[:icon]),
          )
      else
        actor.stored.name = actor.json[:name] if actor.json[:name].present?
        actor.stored.username = actor.json[:preferredUsername] if actor.json[
          :preferredUsername
        ].present?

        if actor.json[:icon].present?
          actor.stored.icon_url = DiscourseActivityPub::JsonLd.resolve_icon_url(actor.json[:icon])
        end
      end

      if actor.json["publicKey"].is_a?(Hash) &&
           actor.json["publicKey"]["owner"] == actor.stored.ap_id
        actor.stored.public_key = actor.json["publicKey"]["publicKeyPem"]
      end

      if actor.stored.new_record? || actor.stored.changed?
        begin
          actor.stored.save!
        rescue ActiveRecord::RecordInvalid => error
          DiscourseActivityPub::Logger.object_store_error(actor, error)
          raise DiscourseActivityPub::AP::Handlers::Error::Store,
                I18n.t(
                  "discourse_activity_pub.process.error.failed_to_save_actor",
                  actor_id: actor.json[:id],
                )
        end
      end
    end
  end

  DiscourseActivityPub::AP::Collection.add_handler(:collection, :store) do |collection|
    collection.stored = DiscourseActivityPubCollection.find_by(ap_id: collection.json[:id])

    DiscourseActivityPubCollection.transaction do
      if collection.stored
        collection.stored.name = collection.json[:name] if collection.json[:name].present?
        collection.stored.audience = collection.json[:audience] if collection.json[
          :audience
        ].present?
      else
        params = {
          local: false,
          ap_id: collection.json[:id],
          ap_type: collection.json[:type],
          name: collection.json[:name],
          audience: collection.json[:audience],
          published_at: collection.json[:published],
        }
        collection.stored = DiscourseActivityPubCollection.new(params)
      end
      if collection.stored.new_record? || collection.stored.changed?
        begin
          collection.stored.save!
        rescue ActiveRecord::RecordInvalid => error
          DiscourseActivityPub::Logger.object_store_error(collection, error)
        end
      end
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:activity, :forward) do |activity|
    DiscourseActivityPub::ActivityForwarder.perform(activity)
  end

  Discourse::Application.routes.prepend do
    mount DiscourseActivityPub::Engine, at: "ap"

    get ".well-known/webfinger" => "discourse_activity_pub/webfinger#index"
    post "/webfinger/handle/validate" => "discourse_activity_pub/webfinger/handle#validate",
         :defaults => {
           format: :json,
         }
    get "u/:username/preferences/activity-pub" => "users#preferences",
        :constraints => {
          username: RouteFormat.username,
        }

    scope module: "discourse_activity_pub", constraints: AdminConstraint.new do
      scope "/admin/plugins" do
        get "ap" => "admin/admin#index"
        get "ap/actor" => "admin/actor#index"
        post "ap/actor" => "admin/actor#create", :constraints => { format: :json }
        get "ap/actor/:actor_id" => "admin/actor#show"
        put "ap/actor/:actor_id" => "admin/actor#update", :constraints => { format: :json }
        post "ap/actor/:actor_id/enable" => "admin/actor#enable"
        post "ap/actor/:actor_id/disable" => "admin/actor#disable"
      end
    end
  end
end
