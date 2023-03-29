# frozen_string_literal: true

Fabricator(:discourse_activity_pub_activity) do
  ap_id { DiscourseActivityPub::JsonLd.json_ld_id("activity", SecureRandom.hex(16)) }
  ap_type { "Activity" }

  before_create do |activity|
    self.actor = Fabricate(:discourse_activity_pub_actor) if !self.actor
  end
end

Fabricator(:discourse_activity_pub_activity_follow, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Follow.type }
  actor { Fabricate(:discourse_activity_pub_actor_person) }
  object { Fabricate(:discourse_activity_pub_actor_group) }
end

Fabricator(:discourse_activity_pub_activity_accept, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Accept.type }
  actor { Fabricate(:discourse_activity_pub_actor_group) }
  object do
    Fabricate(:discourse_activity_pub_activity_follow, actor: Fabricate(:discourse_activity_pub_actor_person))
  end
end

Fabricator(:discourse_activity_pub_activity_reject, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Reject.type }
  actor { Fabricate(:discourse_activity_pub_actor_group) }
  object do
    Fabricate(:discourse_activity_pub_activity_follow, actor: Fabricate(:discourse_activity_pub_actor_person))
  end
end

Fabricator(:discourse_activity_pub_activity_create, from: :discourse_activity_pub_activity) do
  ap_type { DiscourseActivityPub::AP::Activity::Create.type }
  actor { Fabricate(:discourse_activity_pub_actor_group) }
  object { Fabricate(:discourse_activity_pub_object_note) }
end