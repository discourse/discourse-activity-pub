# frozen_string_literal: true

Fabricator(:discourse_activity_pub_actor) do
  uid { sequence(:uid) { |i| "uid#{i}"} }
  domain { "forum.com" }
  ap_type { "Actor" }
  inbox { "https://forum.com/inbox" }
  outbox { "https://forum.com/outbox" }
end

Fabricator(:discourse_activity_pub_actor_person, from: :discourse_activity_pub_actor) do
  ap_type { DiscourseActivityPub::AP::Actor::Person.type }
end

Fabricator(:discourse_activity_pub_actor_group, from: :discourse_activity_pub_actor) do
  ap_type { DiscourseActivityPub::AP::Actor::Group.type }
  model { Fabricate(:category) }
end
