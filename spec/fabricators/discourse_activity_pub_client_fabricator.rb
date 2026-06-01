# frozen_string_literal: true

Fabricator(:discourse_activity_pub_client) { domain { "remote.com" } }

Fabricator(:discourse_activity_pub_client_mastodon, from: :discourse_activity_pub_client) do
  auth_type { DiscourseActivityPubClient.auth_types[:mastodon] }
  credentials { { client_id: "12345", client_secret: "abcde", access_token: "12345" }.as_json }
end
