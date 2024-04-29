# frozen_string_literal: true

Fabricator(:discourse_activity_pub_authorization) do
  domain { "remote.com" }
  user { Fabricate(:user) }
end

Fabricator(
  :discourse_activity_pub_authorization_mastodon,
  from: :discourse_activity_pub_authorization,
) { auth_type { DiscourseActivityPubAuthorization.auth_types[:mastodon] } }

Fabricator(
  :discourse_activity_pub_authorization_discourse,
  from: :discourse_activity_pub_authorization,
) { auth_type { DiscourseActivityPubAuthorization.auth_types[:discourse] } }
