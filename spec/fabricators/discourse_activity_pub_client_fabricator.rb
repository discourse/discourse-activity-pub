# frozen_string_literal: true

Fabricator(:discourse_activity_pub_client) do
  domain { "remote.com" }
end

Fabricator(
  :discourse_activity_pub_client_mastodon,
  from: :discourse_activity_pub_client,
) do
  auth_type { DiscourseActivityPubClient.auth_types[:mastodon] }
  credentials { { client_id: "12345", client_secret: "abcde" }.as_json }
end

Fabricator(
  :discourse_activity_pub_client_discourse,
  from: :discourse_activity_pub_client,
) do
  auth_type { DiscourseActivityPubClient.auth_types[:discourse] }
  credentials {
    { 
      public_key: "-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDh7BS7Ey8hfbNhlNAW/47pqT7wIhBz3UyBYzin8JurEQ2pY9jWWlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFVp16Op3CHLJnnJKKBMNdXMy0yDfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0nw0z/BYpOgZ8QwnI5ZwIDAQAB\n-----END PUBLIC KEY-----",
      private_key: "-----BEGIN RSA PRIVATE KEY-----\nMIICWwIBAAKBgQDh7BS7Ey8hfbNhlNAW/47pqT7wIhBz3UyBYzin8JurEQ2pY9jWWlY8CH147KyIZf1fpcsi7ZNxGHeDhVsbtUKZxnFVp16Op3CHLJnnJKKBMNdXMy0yDfCAHZtqxeBOTcCo1Vt/bHpIgiK5kmaekyXIaD0nw0z/BYpOgZ8QwnI5ZwIDAQABAoGAeHesbjzCivc+KbBybXEEQbBPsThY0Y+VdgD0ewif2U4UnNhzDYnKJeTZExwQvAK2YsRDV3KbhljnkagQduvmgJyCKuV/CxZvbJddwyIs3+U2D4XysQp3e1YZ7ROrYlOIoekHCx1CNm6A4iImqGxB0aJ7Owdk3+QSIaMtGQWaPTECQQDz2UjJ+bomguNszdcv3ZP7W3U5RG+TpInSHiJXpt2JdNGfHItozGJCxfzDhuKHK5Cb23bgldkvB9Xcp/tngTtNAkEA7S4cqUezA82xS7aYPehpRkKEmqzMwR3e9WeL7nZ2cdjZAHgXe49l3mBhidEyRmtPqbXo1Xix8LDuqik0IdnlgwJAQeYTnLnHS8cNjQbnw4C/ECu8Nzi+aokJ0eXg5A0tS4ttZvGA31Z0q5Tz5SdbqqnkT6p0qub0JZiZfCNNdsBe9QJAaGT5fJDwfGYW+YpfLDCV1bUFhMc2QHITZtSyxL0jmSynJwu02k/duKmXhP+tL02gfMRyvTMorxZRllgYeCXeXQJAEGRXR8/26jwqPtKKJzC7i9BuOYEagqj0nLG2YYfffCMcd3JGCf7DMaUlaUE8bJ08PtHRJFSGkNfDJLhLKSjpbw==\n-----END RSA PRIVATE KEY-----"
    }.as_json
  }
end
