# frozen_string_literal: true

# name: discourse-activity-pub
# about: ActivityPub plugin for Discourse
# version: 0.1.0
# authors: Angus McLeod

after_initialize do
  %w(
    ../lib/discourse_activity_pub/engine.rb
    ../lib/discourse_activity_pub/json_ld.rb
    ../lib/discourse_activity_pub/request.rb
    ../lib/discourse_activity_pub/model.rb
    ../lib/discourse_activity_pub/ap.rb
    ../lib/discourse_activity_pub/ap/object.rb
    ../lib/discourse_activity_pub/ap/actor.rb
    ../lib/discourse_activity_pub/ap/actor/group.rb
    ../lib/discourse_activity_pub/ap/actor/person.rb
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
    ../app/models/discourse_activity_pub/ap/concerns/base.rb
    ../app/models/discourse_activity_pub/ap/concerns/activity.rb
    ../app/models/discourse_activity_pub/ap/concerns/model.rb
    ../app/models/discourse_activity_pub_actor.rb
    ../app/models/discourse_activity_pub_activity.rb
    ../app/models/discourse_activity_pub_follow.rb
    ../app/models/discourse_activity_pub_object.rb
    ../app/jobs/discourse_activity_pub_process.rb
    ../app/jobs/discourse_activity_pub_deliver.rb
    ../app/controllers/discourse_activity_pub/ap/collections_controller.rb
    ../app/controllers/discourse_activity_pub/ap/inboxes_controller.rb
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
    ../config/routes.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  Category.has_one :activity_pub_actor, class_name: "DiscourseActivityPubActor", as: :model, dependent: :destroy
  Category.has_many :activity_pub_followers, class_name: "DiscourseActivityPubFollow", through: :activity_pub_actor, source: :followers, dependent: :destroy
  Category.has_many :activity_pub_activities, class_name: "DiscourseActivityPubActivity", through: :activity_pub_actor, source: :activities, dependent: :destroy

  register_category_custom_field_type('activity_pub_enabled', :boolean)
  add_to_class(:category, :full_url) { "#{Discourse.base_url}#{self.url}" }
  add_to_class(:category, :activity_pub_enabled) { SiteSetting.activity_pub_enabled && !!custom_fields["activity_pub_enabled"] }
  add_to_class(:category, :activity_pub_enable!) { custom_fields["activity_pub_enabled"] = true; save! }
  add_to_class(:category, :activity_pub_id) { full_url }
  add_to_class(:category, :activity_pub_type) { DiscourseActivityPub::AP::Actor::Group.type }
  add_to_class(:category, :activity_pub_ready?) { activity_pub_enabled && activity_pub_actor.present? }
  add_model_callback(:category, :after_save) { DiscourseActivityPubActor.ensure_for(self) }

  Post.has_many :activity_pub_objects, class_name: "DiscourseActivityPubObject", as: :model

  add_to_class(:post, :activity_pub_enabled) { SiteSetting.activity_pub_enabled && topic.category&.activity_pub_ready? && is_first_post? }
  add_to_class(:post, :activity_pub_id) { full_url }
  add_to_class(:post, :activity_pub_type) { DiscourseActivityPub::AP::Object::Note.type }
  add_to_class(:post, :activity_pub_content) { PrettyText.excerpt(cooked, SiteSetting.activity_pub_note_excerpt_maxlength, post: self) }
  add_to_class(:post, :activity_pub_actor) { topic.category&.activity_pub_actor }
  add_model_callback(:post, :after_create) { DiscourseActivityPubObject.handle_model_callback(self, :create) }
  add_model_callback(:post, :after_update) { DiscourseActivityPubObject.handle_model_callback(self, :update) }
  add_model_callback(:post, :after_destroy) { DiscourseActivityPubObject.handle_model_callback(self, :delete) }
end