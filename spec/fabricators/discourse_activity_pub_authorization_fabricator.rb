# frozen_string_literal: true

Fabricator(:discourse_activity_pub_authorization) do
  user { Fabricate(:user) }
  actor { Fabricate(:discourse_activity_pub_actor_person) }
end

Fabricator(
  :discourse_activity_pub_authorization_mastodon,
  from: :discourse_activity_pub_authorization,
) { client { Fabricate(:discourse_activity_pub_client_mastodon) } }

Fabricator(
  :discourse_activity_pub_authorization_discourse,
  from: :discourse_activity_pub_authorization,
) { client { Fabricate(:discourse_activity_pub_client_discourse) } }
