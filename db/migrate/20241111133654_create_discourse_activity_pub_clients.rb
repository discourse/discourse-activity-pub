# frozen_string_literal: true
class CreateDiscourseActivityPubClients < ActiveRecord::Migration[7.1]
  def up
    create_table :discourse_activity_pub_clients do |t|
      t.integer :auth_type, null: false
      t.string :domain, null: false
      t.json :credentials, null: false

      t.timestamps
    end

    auth_type = DiscourseActivityPubClient.auth_types[:mastodon]
    allowed_keys = DiscourseActivityPubClient::ALLOWED_CREDENTIAL_KEYS[:mastodon]
    plugin_name = "#{DiscourseActivityPub::PLUGIN_NAME}-oauth-app"

    DB.exec(<<~SQL, auth_type:, allowed_keys:, plugin_name:)
      INSERT INTO discourse_activity_pub_clients(auth_type, domain, credentials, created_at, updated_at)
      SELECT :auth_type, key, (SELECT json_object_agg(key, value) FROM json_each(value::json) WHERE key IN (:allowed_keys)), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM plugin_store_rows
      WHERE plugin_name = :plugin_name AND value IS NOT NULL
    SQL

    add_index :discourse_activity_pub_clients,
              %i[auth_type domain],
              unique: true,
              name: "unique_activity_pub_client_auth_domains"
  end

  def down
    drop_table :discourse_activity_pub_clients
  end
end
