# frozen_string_literal: true

Fabricator(:discourse_activity_pub_follow) do
  follower { Fabricate(:discourse_activity_pub_person) }
  followed { Fabricate(:discourse_activity_pub_group) }
end
