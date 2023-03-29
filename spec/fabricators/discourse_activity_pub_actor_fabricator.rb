# frozen_string_literal: true

Fabricator(:discourse_activity_pub_actor) do
  ap_type { "Actor" }
  domain { "forum.com" }
  username { sequence(:username) { |i| "username#{i}"} }

  after_create do |actor|
    actor.inbox = "#{actor.ap_id}/inbox"
    actor.outbox = "#{actor.ap_id}/outbox"
    actor.save!
  end
end

Fabricator(:discourse_activity_pub_actor_person, from: :discourse_activity_pub_actor) do
  ap_id { sequence(:ap_id) { |i| "https://external.com/actor/#{i}"} }
  ap_type { DiscourseActivityPub::AP::Actor::Person.type }
end

Fabricator(:discourse_activity_pub_actor_group, from: :discourse_activity_pub_actor) do
  ap_type { DiscourseActivityPub::AP::Actor::Group.type }
  model { Fabricate(:category) }
  local { true }
end
