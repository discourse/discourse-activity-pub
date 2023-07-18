# frozen_string_literal: true

Fabricator(:discourse_activity_pub_activity) do
  ap_id { DiscourseActivityPub::JsonLd.json_ld_id("activity", SecureRandom.hex(16)) }
  ap_type { "Activity" }
end

Fabricator(:discourse_activity_pub_activity_follow, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Follow.type }
  actor { Fabricate(:discourse_activity_pub_actor_person) }
  object { Fabricate(:discourse_activity_pub_actor_group) }
end

Fabricator(:discourse_activity_pub_activity_accept, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Accept.type }

  before_create do |activity|
    actor = self.actor || Fabricate(:discourse_activity_pub_actor_group)
    self.actor = actor
    self.object = Fabricate(:discourse_activity_pub_activity_follow,
      actor: Fabricate(:discourse_activity_pub_actor_person),
      object: actor
    )
  end
end

Fabricator(:discourse_activity_pub_activity_reject, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Reject.type }

  before_create do |activity|
    actor = self.actor || Fabricate(:discourse_activity_pub_actor_group)
    self.actor = actor
    self.object = Fabricate(:discourse_activity_pub_activity_follow,
      actor: Fabricate(:discourse_activity_pub_actor_person),
      object: actor
    )
  end
end

Fabricator(:discourse_activity_pub_activity_create, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Create.type }
  actor { Fabricate(:discourse_activity_pub_actor_group) }
  object { Fabricate(:discourse_activity_pub_object_note) }
  local { true }

  after_create do |activity|
    if activity.published_at
      object.model.custom_fields['activity_pub_published_at'] = activity.published_at
      object.model.save_custom_fields(true)
    end
  end
end

Fabricator(:discourse_activity_pub_activity_update, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Update.type }
  actor { Fabricate(:discourse_activity_pub_actor_group) }
  object { Fabricate(:discourse_activity_pub_object_note) }
  local { true }

  after_create do |activity|
    object.model.custom_fields['activity_pub_published_at'] = Time.now
    object.model.save_custom_fields(true)
  end
end

Fabricator(:discourse_activity_pub_activity_delete, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Delete.type }
  actor { Fabricate(:discourse_activity_pub_actor_group) }
  object { Fabricate(:discourse_activity_pub_object_note) }
  local { true }

  after_create do |activity|
    object.model.deleted_at = Time.now

    if activity.published_at
      object.model.custom_fields['activity_pub_deleted_at'] = activity.published_at
    end

    object.model.save!
  end
end