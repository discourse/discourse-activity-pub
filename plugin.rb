# frozen_string_literal: true

# name: discourse-activity-pub
# about: ActivityPub plugin for Discourse
# version: 0.1.0
# authors: Angus McLeod

register_asset "stylesheets/common/common.scss"
register_svg_icon "discourse-activity-pub"

after_initialize do
  %w(
    ../lib/discourse_activity_pub/engine.rb
    ../lib/discourse_activity_pub/json_ld.rb
    ../lib/discourse_activity_pub/uri.rb
    ../lib/discourse_activity_pub/request.rb
    ../lib/discourse_activity_pub/webfinger.rb
    ../lib/discourse_activity_pub/username_validator.rb
    ../lib/discourse_activity_pub/excerpt_parser.rb
    ../lib/discourse_activity_pub/signature_parser.rb
    ../lib/discourse_activity_pub/delivery_failure_tracker.rb
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
    ../lib/discourse_activity_pub/ap/collection.rb
    ../lib/discourse_activity_pub/ap/collection/ordered_collection.rb
    ../app/models/concerns/discourse_activity_pub/ap/identifier_validations.rb
    ../app/models/concerns/discourse_activity_pub/ap/activity_validations.rb
    ../app/models/concerns/discourse_activity_pub/ap/model_validations.rb
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
    ../app/serializers/discourse_activity_pub/ap/collection_serializer.rb
    ../app/serializers/discourse_activity_pub/ap/collection/ordered_collection_serializer.rb
    ../app/serializers/discourse_activity_pub/webfinger_serializer.rb
    ../config/routes.rb
    ../extensions/discourse_activity_pub_category_extension.rb
    ../extensions/discourse_activity_pub_site_extension.rb
    ../extensions/discourse_activity_pub_guardian_extension.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  # Site.activity_pub_enabled is the single source of truth for whether
  # ActivityPub is enabled on the site level. Using module prepension here
  # otherwise Site.activity_pub_enabled would be both using, and subject to,
  # SiteSetting.activity_pub_enabled.
  Site.singleton_class.prepend DiscourseActivityPubSiteExtension
  add_to_serializer(:site, :activity_pub_enabled) { Site.activity_pub_enabled }
  add_to_serializer(:site, :activity_pub_host) { DiscourseActivityPub.host }

  Category.has_one :activity_pub_actor, class_name: "DiscourseActivityPubActor", as: :model, dependent: :destroy
  Category.has_many :activity_pub_followers, class_name: "DiscourseActivityPubActor", through: :activity_pub_actor, source: :followers, dependent: :destroy
  Category.has_many :activity_pub_activities, class_name: "DiscourseActivityPubActivity", through: :activity_pub_actor, source: :activities, dependent: :destroy
  Category.prepend DiscourseActivityPubCategoryExtension

  register_category_custom_field_type('activity_pub_enabled', :boolean)
  register_category_custom_field_type('activity_pub_show_status', :boolean)
  register_category_custom_field_type('activity_pub_username', :string)
  register_category_custom_field_type('activity_pub_name', :string)
  add_to_class(:category, :activity_pub_url) { "#{DiscourseActivityPub.base_url}#{self.url}" }
  add_to_class(:category, :activity_pub_logo_url) { SiteIconManager.large_icon_url }
  add_to_class(:category, :activity_pub_enabled) { Site.activity_pub_enabled && !self.read_restricted && !!custom_fields["activity_pub_enabled"] }
  add_to_class(:category, :activity_pub_show_status) { Site.activity_pub_enabled && !!custom_fields["activity_pub_show_status"] }
  add_to_class(:category, :activity_pub_ready?) { activity_pub_enabled && activity_pub_actor.present? && activity_pub_actor.persisted? }
  add_to_class(:category, :activity_pub_username) { custom_fields["activity_pub_username"] }
  add_to_class(:category, :activity_pub_name) { custom_fields["activity_pub_name"] }
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
    opts[:group_ids] = [Group::AUTO_GROUPS[:staff], *self.reviewable_by_group_id] if !activity_pub_show_status
    MessageBus.publish("/activity-pub", message, opts)
  end

  add_model_callback(:category, :after_save) do
    DiscourseActivityPubActor.ensure_for(self)
    self.activity_pub_publish_state if self.saved_change_to_read_restricted?
  end

  on(:site_setting_changed) do |name, old_val, new_val|
    if %i(activity_pub_enabled login_required).include?(name)
      Category
        .joins("LEFT JOIN category_custom_fields ON categories.id = category_custom_fields.category_id")
        .where("category_custom_fields.name = 'activity_pub_enabled' AND category_custom_fields.value IS NOT NULL")
        .each(&:activity_pub_publish_state)
    end
  end

  add_to_serializer(:basic_category, :activity_pub_enabled) { object.activity_pub_enabled }
  add_to_serializer(:basic_category, :activity_pub_ready) { object.activity_pub_ready? }
  add_to_serializer(:basic_category, :activity_pub_show_status) { object.activity_pub_show_status }
  add_to_serializer(:basic_category, :activity_pub_username) { object.activity_pub_username }
  add_to_serializer(:basic_category, :activity_pub_name) { object.activity_pub_name }
  add_to_serializer(:basic_category, :include_activity_pub_username?) { object.activity_pub_enabled }

  if Site.respond_to? :preloaded_category_custom_fields
    Site.preloaded_category_custom_fields << "activity_pub_enabled"
    Site.preloaded_category_custom_fields << "activity_pub_ready"
    Site.preloaded_category_custom_fields << "activity_pub_show_status"
    Site.preloaded_category_custom_fields << "activity_pub_username"
    Site.preloaded_category_custom_fields << "activity_pub_name"
  end

  add_to_class(:topic, :activity_pub_enabled) { Site.activity_pub_enabled && category&.activity_pub_ready? }
  add_to_class(:topic, :activity_pub_published?) do
    return false unless activity_pub_enabled
    first_post = posts.with_deleted.find_by(post_number: 1)
    first_post&.activity_pub_published?
  end
  add_to_serializer(:topic_view, :activity_pub_enabled) { object.topic.activity_pub_enabled }

  Post.has_one :activity_pub_object, class_name: "DiscourseActivityPubObject", as: :model

  register_post_custom_field_type('activity_pub_published_at', :string)

  add_to_class(:post, :activity_pub_url) { "#{DiscourseActivityPub.base_url}#{self.url}" }
  add_to_class(:post, :activity_pub_enabled) do
    return false unless Site.activity_pub_enabled && is_first_post?
    topic = Topic.with_deleted.find_by(id: self.topic_id)
    topic&.activity_pub_enabled
  end
  add_to_class(:post, :activity_pub_content) do
    if custom_fields['activity_pub_content'].present?
      custom_fields['activity_pub_content']
    else
      DiscourseActivityPub::ExcerptParser.get_content(self)
    end
  end
  add_to_class(:post, :activity_pub_actor) { topic.category&.activity_pub_actor }
  add_to_class(:post, :activity_pub_after_publish) do |published_at|
    custom_fields['activity_pub_published_at'] = published_at
    save_custom_fields(true)
    activity_pub_publish_state
  end
  add_to_class(:post, :activity_pub_published_at) { custom_fields['activity_pub_published_at'] }
  add_to_class(:post, :activity_pub_published?) { !!activity_pub_published_at }
  add_to_class(:post, :activity_pub_publish_state) do
    message = {
      model: {
        id: self.id,
        type: "post",
        published_at: self.activity_pub_published_at
      }
    }
    MessageBus.publish("/activity-pub", message)
  end

  add_to_serializer(:post, :activity_pub_enabled) { object.activity_pub_enabled }
  add_to_serializer(:post, :activity_pub_published_at) { object.activity_pub_published_at }

  # TODO (future): discourse/discourse needs to cook earlier for validators.
  # See also discourse/discourse/plugins/poll/lib/poll.rb.
  on(:before_create_post) do |post|
    post.custom_fields['activity_pub_content'] = DiscourseActivityPub::ExcerptParser.get_content(post)
  end
  on(:before_edit_post) do |post|
    post.custom_fields['activity_pub_content'] = DiscourseActivityPub::ExcerptParser.get_content(post)
  end
  on(:validate_post) do |post|
    if post.activity_pub_published? && post.activity_pub_content != post.activity_pub_object.content
      post.errors.add(:base, I18n.t("post.discourse_activity_pub.error.edit_after_publication"))
    end
  end
  on(:post_edited) do |post, topic_changed, post_revisor|
    DiscourseActivityPubObject.handle_model_callback(post, :update)
  end
  on(:post_created) do |post, opts, user|
    DiscourseActivityPubObject.handle_model_callback(post, :create)
  end
  on(:post_destroyed) do |post, opts, user|
    DiscourseActivityPubObject.handle_model_callback(post, :delete)
  end

  Guardian.prepend DiscourseActivityPubGuardianExtension
end