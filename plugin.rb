# frozen_string_literal: true

# name: discourse-activity-pub
# about: ActivityPub plugin for Discourse
# version: 0.1.0
# authors: Angus McLeod
# meta_topic_id: 266794

enabled_site_setting :activity_pub_enabled

register_asset "stylesheets/common/common.scss"
register_asset "stylesheets/mobile/mobile.scss", :mobile
register_svg_icon "discourse-activity-pub"
register_svg_icon "fingerprint"
register_svg_icon "user-check"
register_svg_icon "circle-arrow-up"
register_svg_icon "circle-arrow-down"

module ::DiscourseActivityPub
  PLUGIN_NAME = "discourse-activity-pub"
end
require_relative "lib/discourse_activity_pub/engine"

require_relative "lib/discourse_activity_pub/plugin/instance.rb"
Plugin::Instance.prepend DiscourseActivityPub::Plugin::Instance

require_relative "validators/activity_pub_signed_requests_validator.rb"

after_initialize do
  ##
  ## Discourse routes
  ##

  add_admin_route "admin.discourse_activity_pub.label", "activityPub"
  Discourse::Application.routes.append do
    mount ::DiscourseActivityPub::Engine, at: "ap"

    get ".well-known/webfinger" => "discourse_activity_pub/webfinger#index"
    get ".well-known/nodeinfo" => "discourse_activity_pub/nodeinfo#index"
    get "/nodeinfo/:version" => "discourse_activity_pub/nodeinfo#show",
        :constraints => {
          version: /[0-9\.]+/,
        }
    post "/webfinger/handle/validate" => "discourse_activity_pub/webfinger/handle#validate",
         :defaults => {
           format: :json,
         }
    get "u/:username/preferences/activity-pub" => "users#preferences",
        :constraints => {
          username: RouteFormat.username,
        }

    scope constraints: AdminConstraint.new do
      get "/admin/plugins/ap" => "admin/plugins#index"
      get "/admin/plugins/ap/actor" => "admin/discourse_activity_pub/actor#index"
      post "/admin/plugins/ap/actor" => "admin/discourse_activity_pub/actor#create",
           :constraints => {
             format: :json,
           }
      get "/admin/plugins/ap/actor/:actor_id" => "admin/discourse_activity_pub/actor#show"
      put "/admin/plugins/ap/actor/:actor_id" => "admin/discourse_activity_pub/actor#update",
          :constraints => {
            format: :json,
          }
      delete "/admin/plugins/ap/actor/:actor_id" => "admin/discourse_activity_pub/actor#delete"
      post "/admin/plugins/ap/actor/:actor_id/restore" =>
             "admin/discourse_activity_pub/actor#restore",
           :constraints => {
             format: :json,
           }
      post "/admin/plugins/ap/actor/:actor_id/enable" => "admin/discourse_activity_pub/actor#enable"
      post "/admin/plugins/ap/actor/:actor_id/disable" =>
             "admin/discourse_activity_pub/actor#disable"
      get "/admin/plugins/ap/log" => "admin/discourse_activity_pub/log#index"
    end
  end

  ##
  ## Discourse models
  ##

  %w[Category Tag].each do |model_type|
    klass = model_type.constantize
    klass.has_one :activity_pub_actor, class_name: "DiscourseActivityPubActor", as: :model
    klass.has_many :activity_pub_followers,
                   through: :activity_pub_actor,
                   source: :followers,
                   class_name: "DiscourseActivityPubActor"
    klass.has_many :activity_pub_follows,
                   through: :activity_pub_actor,
                   source: :follows,
                   class_name: "DiscourseActivityPubActor"
    klass.include DiscourseActivityPub::AP::ModelCallbacks

    class_name = model_type.downcase.to_sym
    add_to_class(class_name, :activity_pub_object) { activity_pub_actor }
    add_to_class(class_name, :activity_pub_url) { "#{DiscourseActivityPub.base_url}#{self.url}" }
    add_to_class(class_name, :activity_pub_icon_url) { DiscourseActivityPub.icon_url }
    add_to_class(class_name, :activity_pub_enabled) do
      DiscourseActivityPub.enabled && !!activity_pub_actor&.enabled
    end
    add_to_class(class_name, :activity_pub_perform_activity?) do
      return false if performing_activity_stop
      return false unless DiscourseActivityPub.publishing_enabled && activity_pub_enabled
      performing_activity&.delete?
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
    add_to_class(class_name, :activity_pub_published?) { activity_pub_actor.present? }
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
    add_to_class(class_name, :activity_pub_publication_type) do
      activity_pub_actor&.publication_type || "full_topic"
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
    add_to_class(class_name, :activity_pub_deleted?) { activity_pub_actor.tombstoned? }
    add_to_class(class_name, :activity_pub_follower_count) { activity_pub_followers.count }
    add_to_class(class_name, :activity_pub_visibility) { "public" }
    add_to_class(class_name, :activity_pub_delete!) { perform_activity_pub_activity(:delete) }
    add_to_class(class_name, :performing_activity_after_perform) do
      if performing_activity.delete? && activity_pub_actor
        if !activity_pub_actor.model || activity_pub_actor.model.destroyed?
          activity_pub_actor.destroy_objects!
          activity_pub_actor.destroy!
        else
          activity_pub_actor.tombstone_objects!
          activity_pub_actor.tombstone!
        end
      end
    end
    add_to_class(class_name, :activity_pub_after_deliver) do |args = {}|
      activity_pub_update_custom_fields(args)
      activity_pub_topic&.activity_pub_publish_state if is_first_post?
    end
    on("#{klass.to_s.downcase}_destroyed".to_sym) do |model|
      actor = DiscourseActivityPubActor.find_by(model_id: model.id, model_type: klass.to_s)
      if actor&.local?
        model.activity_pub_delete!
      elsif actor&.remote?
        actor.destroy_objects!
        actor.destroy!
      end
    end
  end

  User.prepend DiscourseActivityPub::User
  User.activity_pub_custom_fields.each do |field_name, field_type|
    register_user_custom_field_type(field_name, field_type)
    boolean = field_type == :boolean
    method_name = boolean ? "#{field_name}?" : field_name
    add_to_class(:user, method_name.to_sym) do
      if boolean
        ActiveModel::Type::Boolean.new.cast(custom_fields[field_name])
      else
        custom_fields[field_name]
      end
    end
  end
  Guardian.prepend DiscourseActivityPub::Guardian
  Topic.prepend DiscourseActivityPub::Topic
  Post.prepend DiscourseActivityPub::Post
  Post.activity_pub_custom_field_names.each do |field_name|
    register_post_custom_field_type(field_name, :string)
    add_to_class(:post, field_name.to_sym) { custom_fields[field_name] }
  end
  PostAction.prepend DiscourseActivityPub::PostAction
  Statistics.singleton_class.prepend DiscourseActivityPub::Statistics

  ##
  ## Discourse serialization
  ##

  add_permitted_post_create_param(:activity_pub_visibility)

  TopicView.on_preload do |topic_view|
    if topic_view.topic.activity_pub_enabled
      Post.preload_custom_fields(topic_view.posts, Post.activity_pub_custom_field_names)
      ActiveRecord::Associations::Preloader.new(
        records: topic_view.posts,
        associations: [:activity_pub_object],
      ).call
    end
  end

  add_to_serializer(:site, :activity_pub_enabled) { DiscourseActivityPub.enabled }
  add_to_serializer(:site, :activity_pub_publishing_enabled) do
    DiscourseActivityPub.publishing_enabled
  end
  add_to_serializer(:site, :activity_pub_host) { DiscourseActivityPub.host }
  add_to_serializer(:site, :activity_pub_actors) do
    actors = { category: [], tag: [] }
    DiscourseActivityPubActor.active.each do |actor|
      actors[actor.model_type.downcase.to_sym] << DiscourseActivityPub::SiteActorSerializer.new(
        actor,
        root: false,
      ).as_json
    end
    actors.as_json
  end
  add_to_serializer(:post, :activity_pub_enabled) { object.activity_pub_enabled }
  add_to_serializer(:web_hook_post, :activity_pub_enabled, include_condition: -> { false }) do
    false
  end
  Post.activity_pub_custom_field_names.each do |field_name|
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
    :activity_pub_object_id,
    include_condition: -> { object.activity_pub_enabled },
  ) { object.activity_pub_object_id }
  add_to_serializer(:web_hook_topic_view, :activity_pub_enabled, include_condition: -> { false }) do
    false
  end
  add_to_serializer(:topic_view, :activity_pub_enabled) { object.topic.activity_pub_enabled }
  add_to_serializer(
    :topic_view,
    :activity_pub_local,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_local? }
  add_to_serializer(
    :topic_view,
    :activity_pub_deleted_at,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_deleted_at }
  add_to_serializer(
    :topic_view,
    :activity_pub_published_at,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_published_at }
  add_to_serializer(
    :topic_view,
    :activity_pub_scheduled_at,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_scheduled_at }
  add_to_serializer(
    :topic_view,
    :activity_pub_delivered_at,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_delivered_at }
  add_to_serializer(
    :topic_view,
    :activity_pub_full_topic,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_full_topic }
  add_to_serializer(
    :topic_view,
    :activity_pub_published_post_count,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_published_post_count }
  add_to_serializer(
    :topic_view,
    :activity_pub_total_post_count,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_total_post_count }
  add_to_serializer(
    :topic_view,
    :activity_pub_object_id,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_object&.ap_id }
  add_to_serializer(
    :topic_view,
    :activity_pub_object_type,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) { object.topic.activity_pub_object&.ap_type }
  add_to_serializer(
    :topic_view,
    :activity_pub_actor,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) do
    DiscourseActivityPub::ActorSerializer.new(object.topic.activity_pub_actor, root: false).as_json
  end
  add_to_serializer(
    :topic_view,
    :activity_pub_post_actors,
    include_condition: -> { object.topic.activity_pub_enabled },
  ) do
    object.topic.activity_pub_post_actors.map do |post_actor|
      {
        post_id: post_actor.post_id,
        actor: DiscourseActivityPub::BasicActorSerializer.new(post_actor, root: false).as_json,
      }
    end
  end

  ##
  ## Discourse events
  ##

  on(:site_setting_changed) do |name, old_val, new_val|
    if %i[activity_pub_enabled login_required].include?(name)
      DiscourseActivityPubActor.active.each { |actor| actor.model.activity_pub_publish_state }
    end
  end
  on(:before_edit_post) do |post|
    # TODO (future): discourse/discourse needs to cook earlier for validators.
    # See also discourse/discourse/plugins/poll/lib/poll.rb.
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
  on(:post_destroyed) do |post, opts, user|
    if post.activity_pub_enabled
      post_object = DiscourseActivityPubObject.find_by(model_id: post.id, model_type: "Post")

      if post_object&.local?
        post.activity_pub_delete!
      elsif post_object&.remote?
        if opts[:force_destroy]
          post_object.destroy!
        else
          post_object.tombstone!
        end
      end

      if post.is_first_post?
        topic_object =
          DiscourseActivityPubCollection.find_by(model_id: post.topic_id, model_type: "Topic")

        if topic_object&.local?
          post.topic.activity_pub_delete!
        elsif topic_object&.remote?
          if opts[:force_destroy]
            topic_object.destroy!
          else
            topic_object.tombstone!
          end
        end
      end
    end
  end
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
    actor = DiscourseActivityPubActor.find_by(model_id: source_user.id, model_type: "User")
    if actor
      update_args =
        (
          if actor.local?
            { model_id: target_user.id, model_type: "User" }
          else
            { model_id: nil, model_type: nil }
          end
        )
      actor.update_columns(update_args)
    end
  end
  on(:user_destroyed) do |user|
    actor = DiscourseActivityPubActor.find_by(model_id: user.id, model_type: "User")
    if actor
      actor.destroy_objects!
      actor.destroy!
    end
  end

  ##
  ## Discourse authentication
  ##

  add_user_api_key_scope(:read, methods: :get, actions: "discourse_activity_pub/actor#find_by_user")
  DiscourseActivityPubClient.update_scope_settings
  on_enabled_change { DiscourseActivityPubClient.update_scope_settings }

  ##
  ## ActivityPub processing (incoming activities)
  ##

  activity_pub_on(:activity, :validate) do |activity|
    if DiscourseActivityPubActivity.exists?(ap_id: activity.json[:id])
      raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
            I18n.t("discourse_activity_pub.process.warning.activity_already_processed")
    end
  end
  activity_pub_on(:create, :validate) do |activity|
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
            model_type: DiscourseActivityPubActor::GROUP_MODELS,
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
  activity_pub_on(:delete, :validate) do |activity|
    if activity.object.stored.is_a?(DiscourseActivityPubActor) && activity.object.stored.local?
      raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
            I18n.t("discourse_activity_pub.process.warning.actor_cannot_be_deleted")
    elsif activity.object.stored.is_a?(DiscourseActivityPubObject)
      DiscourseActivityPub::PostHandler.ensure_activity_has_post(activity)
    end
  end
  activity_pub_on(:update, :validate) do |activity|
    DiscourseActivityPub::PostHandler.ensure_activity_has_post(activity)
  end
  activity_pub_on(:like, :validate) do |activity|
    DiscourseActivityPub::PostHandler.ensure_activity_has_post(activity)
  end
  activity_pub_on(:announce, :validate) do |activity|
    unless DiscourseActivityPub::JsonLd.publicly_addressed?(activity.json)
      raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
            I18n.t("discourse_activity_pub.process.warning.announce_not_publicly_addressed")
    end

    if activity.object.object?
      DiscourseActivityPub::AP::Activity.apply_handlers(activity, :create, :validate)
    end
  end
  activity_pub_on(:create, :perform) do |activity|
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
  activity_pub_on(:delete, :perform) do |activity|
    stored = activity.object.stored

    if stored
      destroy = !!activity.object.cache["delete_object"] && stored.remote?
      delete_user = stored.is_a?(DiscourseActivityPubActor) && stored.model.is_a?(User)
      delete_posts = stored.is_a?(DiscourseActivityPubObject) && stored.model.is_a?(Post)

      if delete_user || delete_posts
        reason = I18n.t("discourse_activity_pub.post.deleted", object_type: activity.object.type)
        args = { destroy: destroy, context: "#{DiscourseActivityPub::Logger::PREFIX} #{reason}" }
        if delete_user
          user = stored.model
          DiscourseActivityPub::PostHandler.delete_users_posts(user, **args)
          DiscourseActivityPub::ActorHandler.delete_user(user, destroy: destroy)
        elsif delete_posts
          post = stored.model
          DiscourseActivityPub::PostHandler.delete_post(post, **args)
        end
      else
        stored.tombstone!
      end
    end
  end
  activity_pub_on(:update, :perform) do |activity|
    post = activity.object.stored.model
    revisor = PostRevisor.new(post)
    revisor.revise!(post.user, { raw: activity.object.content })
  end
  activity_pub_on(:like, :perform) do |activity|
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
  activity_pub_on(:undo, :perform) do |activity|
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
  activity_pub_on(:reject, :perform) do |activity|
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
  activity_pub_on(:announce, :perform) do |activity|
    DiscourseActivityPub::AP::Activity.apply_handlers(activity, :create, :perform)
  end
  activity_pub_on(:follow, :respond_to) do |activity|
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
  activity_pub_on(:accept, :perform) do |activity|
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
  activity_pub_on(:activity, :store) do |activity|
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
  activity_pub_on(:object, :resolve) do |object, opts|
    activity = opts[:parent]

    stored =
      if activity&.delete?
        DiscourseActivityPubObject.find_by(ap_id: object.json[:id]) ||
          DiscourseActivityPubActor.find_by(ap_id: object.json[:id])
      elsif activity&.composition? || (object.object? && activity&.announce?)
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
  activity_pub_on(:object, :store) do |object, opts|
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

          if object.json[:attachment].present?
            object.json[:attachment].each do |json|
              attachment = DiscourseActivityPub::AP::Object.factory(json)
              if attachment
                # Some platforms (e.g. Mastodon) put attachment url media types on the attachment itself,
                # instead of on a Link object in the url attribute. Technically this violates the specification,
                # but we need to support it nevertheless. See further https://www.w3.org/TR/activitystreams-vocabulary/#dfn-mediatype
                media_type = attachment.url.media_type || attachment.media_type
                name = attachment.url.name || attachment.name

                begin
                  DiscourseActivityPubAttachment.create(
                    object_id: object.stored.id,
                    object_type: "DiscourseActivityPubObject",
                    ap_type: attachment.type,
                    url: attachment.url.href,
                    name: name,
                    media_type: media_type,
                  )
                rescue ActiveRecord::RecordInvalid => error
                  # fail silently if an attachment does not validate
                end
              end
            end
          end
        end
      end
    end
  end
  activity_pub_on(:actor, :store) do |actor|
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
  activity_pub_on(:collection, :store) do |collection|
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
  activity_pub_on(:activity, :forward) do |activity|
    DiscourseActivityPub::ActivityForwarder.perform(activity)
  end
end
