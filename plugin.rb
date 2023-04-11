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
    ../lib/discourse_activity_pub/model.rb
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

  Category.has_one :activity_pub_actor, class_name: "DiscourseActivityPubActor", as: :model, dependent: :destroy
  Category.has_many :activity_pub_followers, class_name: "DiscourseActivityPubActor", through: :activity_pub_actor, source: :followers, dependent: :destroy
  Category.has_many :activity_pub_activities, class_name: "DiscourseActivityPubActivity", through: :activity_pub_actor, source: :activities, dependent: :destroy
  Category.prepend DiscourseActivityPubCategoryExtension

  register_category_custom_field_type('activity_pub_enabled', :boolean)
  register_category_custom_field_type('activity_pub_show_status', :boolean)
  register_category_custom_field_type('activity_pub_username', :string)
  add_to_class(:category, :full_url) { "#{Discourse.base_url}#{self.url}" }
  add_to_class(:category, :activity_pub_enabled) { Site.activity_pub_enabled && !!custom_fields["activity_pub_enabled"] }
  add_to_class(:category, :activity_pub_show_status) { Site.activity_pub_enabled && !!custom_fields["activity_pub_show_status"] }
  add_to_class(:category, :activity_pub_ready?) { activity_pub_enabled && activity_pub_actor.present? && activity_pub_actor.persisted? }
  add_to_class(:category, :activity_pub_username) { custom_fields["activity_pub_username"] }
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
  add_model_callback(:category, :after_commit) { DiscourseActivityPubActor.ensure_for(self) }

  add_to_serializer(:basic_category, :activity_pub_enabled) { object.activity_pub_enabled }
  add_to_serializer(:basic_category, :activity_pub_ready) { object.activity_pub_ready? }
  add_to_serializer(:basic_category, :activity_pub_show_status) { object.activity_pub_show_status }
  add_to_serializer(:basic_category, :activity_pub_username) { object.activity_pub_username }
  add_to_serializer(:basic_category, :include_activity_pub_username?) { object.activity_pub_enabled }

  if Site.respond_to? :preloaded_category_custom_fields
    Site.preloaded_category_custom_fields << "activity_pub_enabled"
    Site.preloaded_category_custom_fields << "activity_pub_ready"
    Site.preloaded_category_custom_fields << "activity_pub_show_status"
    Site.preloaded_category_custom_fields << "activity_pub_username"
  end

  Post.has_many :activity_pub_objects, class_name: "DiscourseActivityPubObject", as: :model

  add_to_class(:post, :activity_pub_enabled) do
    return false unless Site.activity_pub_enabled && is_first_post?
    topic = Topic.with_deleted.find_by(id: self.topic_id)
    topic&.category&.activity_pub_ready?
  end
  add_to_class(:post, :activity_pub_content) { DiscourseActivityPub::ExcerptParser.get_excerpt(cooked, SiteSetting.activity_pub_note_excerpt_maxlength, post: self) }
  add_to_class(:post, :activity_pub_actor) { topic.category&.activity_pub_actor }
  add_to_class(:post, :activity_pub_pre_publication?) { Time.now < (created_at + SiteSetting.activity_pub_delivery_delay_minutes.to_i.minutes) }

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