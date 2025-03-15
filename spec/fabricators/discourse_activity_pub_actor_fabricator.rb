# frozen_string_literal: true

Fabricator(:discourse_activity_pub_actor) do
  transient :actor_domain
  ap_type { "Actor" }
  domain { DiscourseActivityPub.host }
  username { sequence(:username) { |i| "username#{i}" } }

  DiscourseActivityPub::Logger.warn("FABRICATOR" + (self.ap_id || "NO ID") + "-----" + local ? "LOCAL" : "NOT LOCAL")
  
  before_create do |actor, transient|
    self.domain = (transient[:actor_domain] || "remote.com") unless local
    self.ap_id = "https://#{self.domain}/actor/#{SecureRandom.hex(16)}" unless self.ap_id || local
  end

  after_create do |actor|
    actor.inbox = "#{actor.ap_id}/inbox"
    actor.outbox = "#{actor.ap_id}/outbox"
    actor.save!
  end
end

Fabricator(:discourse_activity_pub_actor_person, from: :discourse_activity_pub_actor) do
  ap_type { DiscourseActivityPub::AP::Actor::Person.type }
end

Fabricator(:discourse_activity_pub_actor_group, from: :discourse_activity_pub_actor) do
  ap_type { DiscourseActivityPub::AP::Actor::Group.type }
  model { Fabricate(:category) }
  local { true }
end

Fabricator(:discourse_activity_pub_actor_application, from: :discourse_activity_pub_actor) do
  id { DiscourseActivityPubActor::APPLICATION_ACTOR_ID }
  username { DiscourseActivityPubActor::APPLICATION_ACTOR_USERNAME }
  ap_type { DiscourseActivityPub::AP::Actor::Application.type }
  local { true }
end

Fabricator(:discourse_activity_pub_actor_service, from: :discourse_activity_pub_actor) do
  ap_type { DiscourseActivityPub::AP::Actor::Service.type }
end
