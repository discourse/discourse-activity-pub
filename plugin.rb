# frozen_string_literal: true

# name: discourse-activity-pub
# about: ActivityPub plugin for Discourse
# version: 0.1.0
# authors: Angus McLeod

register_asset "stylesheets/common/common.scss"
register_svg_icon "discourse-activity-pub"

after_initialize do
  %w[
    ../lib/discourse_activity_pub/engine.rb
    ../lib/discourse_activity_pub/json_ld.rb
    ../lib/discourse_activity_pub/uri.rb
    ../lib/discourse_activity_pub/request.rb
    ../lib/discourse_activity_pub/webfinger.rb
    ../lib/discourse_activity_pub/username_validator.rb
    ../lib/discourse_activity_pub/content_parser.rb
    ../lib/discourse_activity_pub/signature_parser.rb
    ../lib/discourse_activity_pub/delivery_failure_tracker.rb
    ../lib/discourse_activity_pub/user_handler.rb
    ../lib/discourse_activity_pub/post_handler.rb
    ../lib/discourse_activity_pub/ap.rb
    ../lib/discourse_activity_pub/ap/object.rb
    ../lib/discourse_activity_pub/ap/actor.rb
    ../lib/discourse_activity_pub/ap/actor/group.rb
    ../lib/discourse_activity_pub/ap/actor/person.rb
    ../lib/discourse_activity_pub/ap/actor/application.rb
    ../lib/discourse_activity_pub/ap/activity.rb
    ../lib/discourse_activity_pub/ap/activity/follow.rb
    ../lib/discourse_activity_pub/ap/activity/response.rb
    ../lib/discourse_activity_pub/ap/activity/accept.rb
    ../lib/discourse_activity_pub/ap/activity/reject.rb
    ../lib/discourse_activity_pub/ap/activity/compose.rb
    ../lib/discourse_activity_pub/ap/activity/create.rb
    ../lib/discourse_activity_pub/ap/activity/delete.rb
    ../lib/discourse_activity_pub/ap/activity/update.rb
    ../lib/discourse_activity_pub/ap/activity/undo.rb
    ../lib/discourse_activity_pub/ap/object/note.rb
    ../lib/discourse_activity_pub/ap/object/article.rb
    ../lib/discourse_activity_pub/ap/collection.rb
    ../lib/discourse_activity_pub/ap/collection/ordered_collection.rb
    ../app/models/concerns/discourse_activity_pub/ap/identifier_validations.rb
    ../app/models/concerns/discourse_activity_pub/ap/activity_validations.rb
    ../app/models/concerns/discourse_activity_pub/ap/model_validations.rb
    ../app/models/concerns/discourse_activity_pub/ap/model_callbacks.rb
    ../app/models/concerns/discourse_activity_pub/ap/model_helpers.rb
    ../app/models/concerns/discourse_activity_pub/webfinger_actor_attributes.rb
    ../app/models/discourse_activity_pub_actor.rb
    ../app/models/discourse_activity_pub_activity.rb
    ../app/models/discourse_activity_pub_follow.rb
    ../app/models/discourse_activity_pub_object.rb
    ../app/jobs/discourse_activity_pub_process.rb
    ../app/jobs/discourse_activity_pub_deliver.rb
    ../app/controllers/concerns/discourse_activity_pub/domain_verification.rb
    ../app/controllers/concerns/discourse_activity_pub/signature_verification.rb
    ../app/controllers/discourse_activity_pub/ap/objects_controller.rb
    ../app/controllers/discourse_activity_pub/ap/actors_controller.rb
    ../app/controllers/discourse_activity_pub/ap/inboxes_controller.rb
    ../app/controllers/discourse_activity_pub/ap/outboxes_controller.rb
    ../app/controllers/discourse_activity_pub/ap/followers_controller.rb
    ../app/controllers/discourse_activity_pub/webfinger_controller.rb
    ../app/serializers/discourse_activity_pub/ap/object_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/response_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/accept_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/reject_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/follow_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/compose_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/create_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/delete_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/activity/update_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/actor_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/actor/group_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/actor/person_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/object/note_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/object/article_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/collection_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/collection/ordered_collection_serializer.rb
    ../app/serializers/discourse_activity_pub/webfinger_serializer.rb
    ../config/routes.rb
    ../extensions/discourse_activity_pub_category_extension.rb
    ../extensions/discourse_activity_pub_site_extension.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  # Site.activity_pub_enabled is the single source of truth for whether
  # ActivityPub is enabled on the site level. Using module prepension here
  # otherwise Site.activity_pub_enabled would be both using, and subject to,
  # SiteSetting.activity_pub_enabled.
  Site.singleton_class.prepend DiscourseActivityPubSiteExtension
  add_to_serializer(:site, :activity_pub_enabled) { Site.activity_pub_enabled }
  add_to_serializer(:site, :activity_pub_host) { DiscourseActivityPub.host }

  Category.has_one :activity_pub_actor,
                   class_name: "DiscourseActivityPubActor",
                   as: :model,
                   dependent: :destroy
  Category.has_many :activity_pub_followers,
                    class_name: "DiscourseActivityPubActor",
                    through: :activity_pub_actor,
                    source: :followers,
                    dependent: :destroy
  Category.has_many :activity_pub_activities,
                    class_name: "DiscourseActivityPubActivity",
                    through: :activity_pub_actor,
                    source: :activities,
                    dependent: :destroy
  Category.prepend DiscourseActivityPubCategoryExtension

  register_category_custom_field_type("activity_pub_enabled", :boolean)
  register_category_custom_field_type("activity_pub_show_status", :boolean)
  register_category_custom_field_type("activity_pub_show_handle", :boolean)
  register_category_custom_field_type("activity_pub_username", :string)
  register_category_custom_field_type("activity_pub_name", :string)
  register_category_custom_field_type("activity_pub_default_visibility", :string)
  register_category_custom_field_type("activity_pub_post_object_type", :string)
  register_category_custom_field_type("activity_pub_publication_type", :string)

  add_to_class(:category, :activity_pub_url) do
    "#{DiscourseActivityPub.base_url}#{self.url}"
  end
  add_to_class(:category, :activity_pub_logo_url) do
    SiteIconManager.large_icon_url
  end
  add_to_class(:category, :activity_pub_enabled) do
    Site.activity_pub_enabled && !self.read_restricted &&
      !!custom_fields["activity_pub_enabled"]
  end
  add_to_class(:category, :activity_pub_show_status) do
    Site.activity_pub_enabled && !!custom_fields["activity_pub_show_status"]
  end
  add_to_class(:category, :activity_pub_show_handle) do
    Site.activity_pub_enabled && !!custom_fields["activity_pub_show_handle"]
  end
  add_to_class(:category, :activity_pub_ready?) do
    activity_pub_enabled && activity_pub_actor.present? &&
      activity_pub_actor.persisted?
  end
  add_to_class(:category, :activity_pub_username) do
    custom_fields["activity_pub_username"]
  end
  add_to_class(:category, :activity_pub_name) do
    custom_fields["activity_pub_name"]
  end
  add_to_class(:category, :activity_pub_publish_state) do
    message = {
      model: {
        id: self.id,
        type: "category",
        ready: activity_pub_ready?,
        enabled: activity_pub_enabled
      }
    }
    opts = {}
    opts[:group_ids] = [
      Group::AUTO_GROUPS[:staff],
      *self.reviewable_by_group_id
    ] if !activity_pub_show_status
    MessageBus.publish("/activity-pub", message, opts)
  end
  add_to_class(:category, :activity_pub_default_visibility) do
    custom_fields["activity_pub_default_visibility"] || DiscourseActivityPubActivity.default_visibility
  end
  add_to_class(:category, :activity_pub_post_object_type) do
    custom_fields["activity_pub_post_object_type"]
  end
  add_to_class(:category, :activity_pub_default_object_type) do
    DiscourseActivityPub::AP::Actor::Group.type
  end
  add_to_class(:category, :activity_pub_publication_type) do
    custom_fields["activity_pub_publication_type"] || 'first_post'
  end
  add_to_class(:category, :activity_pub_first_post) do
    activity_pub_publication_type === 'first_post'
  end
  add_to_class(:category, :activity_pub_full_topic) do
    activity_pub_publication_type === 'full_topic'
  end

  add_model_callback(:category, :after_save) do
    DiscourseActivityPubActor.ensure_for(self)
    self.activity_pub_publish_state if self.saved_change_to_read_restricted?
  end

  on(:site_setting_changed) do |name, old_val, new_val|
    if %i[activity_pub_enabled login_required].include?(name)
      Category
        .joins(
          "LEFT JOIN category_custom_fields ON categories.id = category_custom_fields.category_id"
        )
        .where(
          "category_custom_fields.name = 'activity_pub_enabled' AND category_custom_fields.value IS NOT NULL"
        )
        .each(&:activity_pub_publish_state)
    end
  end

  add_to_serializer(:basic_category, :activity_pub_enabled) do
    object.activity_pub_enabled
  end
  add_to_serializer(
    :basic_category,
    :activity_pub_ready,
    include_condition: -> { object.activity_pub_enabled }
  ) { object.activity_pub_ready? }
  add_to_serializer(
    :basic_category,
    :activity_pub_username,
    include_condition: -> { object.activity_pub_enabled }
  ) { object.activity_pub_username }
  add_to_serializer(
    :basic_category,
    :activity_pub_name,
    include_condition: -> { object.activity_pub_enabled }
  ) { object.activity_pub_name }
  add_to_serializer(
    :basic_category,
    :activity_pub_show_status,
    include_condition: -> { object.activity_pub_enabled }
  ) { object.activity_pub_show_status }
  add_to_serializer(
    :basic_category,
    :activity_pub_show_handle,
    include_condition: -> { object.activity_pub_enabled }
  ) { object.activity_pub_show_handle }
  add_to_serializer(
    :basic_category,
    :activity_pub_default_visibility,
    include_condition: -> { object.activity_pub_enabled }
  ) { object.activity_pub_default_visibility }

  if Site.respond_to? :preloaded_category_custom_fields
    Site.preloaded_category_custom_fields << "activity_pub_enabled"
    Site.preloaded_category_custom_fields << "activity_pub_ready"
    Site.preloaded_category_custom_fields << "activity_pub_show_status"
    Site.preloaded_category_custom_fields << "activity_pub_show_handle"
    Site.preloaded_category_custom_fields << "activity_pub_username"
    Site.preloaded_category_custom_fields << "activity_pub_name"
    Site.preloaded_category_custom_fields << "activity_pub_default_visibility"
  end

  add_to_class(:topic, :activity_pub_enabled) do
    Site.activity_pub_enabled && category&.activity_pub_ready?
  end
  add_to_class(:topic, :activity_pub_published?) do
    return false unless activity_pub_enabled

    first_post = posts.with_deleted.find_by(post_number: 1)
    first_post&.activity_pub_published?
  end
  add_to_serializer(:topic_view, :activity_pub_enabled) do
    object.topic.activity_pub_enabled
  end

  Post.has_one :activity_pub_object,
               class_name: "DiscourseActivityPubObject",
               as: :model
  Post.include DiscourseActivityPub::AP::ModelCallbacks
  Post.include DiscourseActivityPub::AP::ModelHelpers

  activity_pub_post_custom_fields = %i[
    scheduled_at
    published_at
    deleted_at
    updated_at
    visibility
  ]
  activity_pub_post_custom_fields.each do |field_name|
    register_post_custom_field_type("activity_pub_#{field_name.to_s}", :string)
  end

  add_permitted_post_create_param(:activity_pub_visibility)

  add_to_class(:post, :activity_pub_url) do
    "#{DiscourseActivityPub.base_url}#{self.url}"
  end
  add_to_class(:post, :activity_pub_enabled) do
    return false unless Site.activity_pub_enabled

    topic = Topic.with_deleted.find_by(id: self.topic_id)
    return false unless topic&.activity_pub_enabled

    is_first_post? || topic.category.activity_pub_full_topic
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
    return nil unless activity_pub_enabled

    topic.category&.activity_pub_actor
  end
  add_to_class(:post, :activity_pub_update_custom_fields) do |args = {}|
    return nil if !activity_pub_enabled || (args.keys & activity_pub_post_custom_fields).empty?
    args.keys.each do |key|
      custom_fields["activity_pub_#{key.to_s}"] = args[key]
    end
    save_custom_fields(true)
    activity_pub_publish_state
  end
  add_to_class(:post, :activity_pub_after_publish) do |args = {}|
    activity_pub_update_custom_fields(args)
  end
  add_to_class(:post, :activity_pub_after_scheduled) do |args = {}|
    activity_pub_update_custom_fields(args)
  end
  add_to_class(:post, :activity_pub_scheduled_at) do
    custom_fields["activity_pub_scheduled_at"]
  end
  activity_pub_post_custom_fields.each do |field_name|
    add_to_class(:post, "activity_pub_#{field_name}".to_sym) do
      custom_fields["activity_pub_#{field_name}"]
    end
  end
  add_to_class(:post, :activity_pub_updated_at) do
    custom_fields["activity_pub_updated_at"]
  end
  add_to_class(:post, :activity_pub_visibility) do
    custom_fields["activity_pub_visibility"] || topic.category&.activity_pub_default_visibility
  end
  add_to_class(:post, :activity_pub_published?) { !!activity_pub_published_at }
  add_to_class(:post, :activity_pub_deleted?) { !!activity_pub_deleted_at }
  add_to_class(:post, :activity_pub_publish_state) do
    return false unless activity_pub_enabled

    topic = Topic.with_deleted.find_by(id: self.topic_id)
    return false unless topic

    model = {
      id: self.id,
      type: "post"
    }

    activity_pub_post_custom_fields.each do |field_name|
      model[field_name.to_sym] = self.send("activity_pub_#{field_name.to_s}")
    end

    group_ids =[
      Group::AUTO_GROUPS[:staff],
      *topic.category.reviewable_by_group_id
    ]

    MessageBus.publish("/activity-pub", { model: model }, { group_ids: group_ids })
  end
  add_to_class(:post, :before_clear_all_activity_pub_objects) do
    activity_pub_post_custom_fields.each do |field_name|
      self.custom_fields["activity_pub_#{field_name.to_s}"] = nil
    end
    self.save_custom_fields(true)
  end
  add_to_class(:post, :before_perform_activity_pub_activity) do |performing_activity|
    return performing_activity if self.activity_pub_published?

    if performing_activity.delete?
      self.clear_all_activity_pub_objects
      self.activity_pub_publish_state
      return nil
    end

    performing_activity
  end
  add_to_class(:post, :activity_pub_object_type) do
    self.activity_pub_object&.ap_type || self.activity_pub_default_object_type
  end
  add_to_class(:post, :activity_pub_default_object_type) do
    self.topic&.category&.activity_pub_post_object_type ||
    DiscourseActivityPub::AP::Object::Note.type
  end

  add_to_serializer(:post, :activity_pub_enabled) do
    object.activity_pub_enabled
  end
  activity_pub_post_custom_fields.each do |field_name|
    add_to_serializer(:post, "activity_pub_#{field_name}".to_sym) do
      object.send("activity_pub_#{field_name}")
    end
  end
  add_to_serializer(:post, :activity_pub_updated_at) do
    object.activity_pub_updated_at
  end

  # TODO (future): discourse/discourse needs to cook earlier for validators.
  # See also discourse/discourse/plugins/poll/lib/poll.rb.
  on(:before_edit_post) do |post|
    if post.activity_pub_enabled
      post.custom_fields[
        "activity_pub_content"
      ] = DiscourseActivityPub::ContentParser.get_content(post)
    end
  end
  on(:post_edited) do |post, topic_changed, post_revisor|
    post.perform_activity_pub_activity(:update) if post.activity_pub_enabled
  end
  on(:post_created) do |post, post_opts, user|
    if post.activity_pub_enabled
      post.custom_fields[
        "activity_pub_content"
      ] = DiscourseActivityPub::ContentParser.get_content(post)
      if post.is_first_post?
        post.custom_fields[
          "activity_pub_visibility"
        ] = post.topic&.category.activity_pub_default_visibility
      else
        post.custom_fields[
          "activity_pub_visibility"
        ] = post.topic.first_post.activity_pub_visibility
      end
      post.save_custom_fields(true)
      post.perform_activity_pub_activity(:create)
    end
  end
  on(:post_destroyed) do |post, opts, user|
    post.perform_activity_pub_activity(:delete) if post.activity_pub_enabled
  end
  on(:post_recovered) do |post, opts, user|
    post.perform_activity_pub_activity(:create) if post.activity_pub_enabled
  end

  DiscourseActivityPub::AP::Activity.add_handler(:undo, :perform) do |actor, object|
    case object.type
    when DiscourseActivityPub::AP::Activity::Follow.type
      DiscourseActivityPubFollow.where(
        follower_id: actor.stored.id,
        followed_id: object.object.stored.id
      ).destroy_all
    else
      false
    end
  end

  User.has_one :activity_pub_actor,
               class_name: "DiscourseActivityPubActor",
               as: :model,
               dependent: :destroy

  # TODO: This should just be part of discourse/discourse.
  User.skip_callback :create, :after, :create_email_token, if: -> { self.skip_email_validation }

  DiscourseActivityPub::AP::Activity.add_handler(:create, :validate) do |actor, object|
    unless actor.person?
      raise DiscourseActivityPub::AP::Activity::ValidationError,
        I18n.t('discourse_activity_pub.process.warning.invalid_create_actor')
    end

    unless object.stored.in_reply_to_post
      raise DiscourseActivityPub::AP::Activity::ValidationError,
        I18n.t('discourse_activity_pub.process.warning.not_a_reply')
    end

    if object.stored.in_reply_to_post.trashed?
      raise DiscourseActivityPub::AP::Activity::ValidationError,
        I18n.t('discourse_activity_pub.process.warning.cannot_reply_to_deleted_post')
    end
  end

  DiscourseActivityPub::AP::Activity.add_handler(:create, :perform) do |actor, object|
    user = DiscourseActivityPub::UserHandler.find_or_create(actor)

    unless user
      raise DiscourseActivityPub::AP::Activity::PerformanceError,
        I18n.t('discourse_activity_pub.create.failed_to_create_user',
          actor_id: actor.id
        )
    end

    post = DiscourseActivityPub::PostHandler.create(user, object)

    unless post
      raise DiscourseActivityPub::AP::Activity::PerformanceError,
        I18n.t('discourse_activity_pub.create.failed_to_create_post',
          user_id: user.id,
          object_id: object.id
        )
    end
  end
end
