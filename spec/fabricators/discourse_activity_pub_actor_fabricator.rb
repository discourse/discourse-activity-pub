# frozen_string_literal: true

Fabricator(:discourse_activity_pub_actor) do
  uid { sequence(:uid) { |i| "actor#{i}"} }
  domain { "forum.com" }
  ap_type { "Actor" }
  preferred_username { sequence(:preferred_username) { |i| "username#{i}"} }
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
