# frozen_string_literal: true
class CreateDiscourseActivityPubClients < ActiveRecord::Migration[7.1]
  def change
    create_table :discourse_activity_pub_clients do |t|
      t.integer :auth_type, null: false
      t.string :domain, null: false
      t.json :credentials, null: false

      t.timestamps
    end
 
    execute <<~SQL
      INSERT INTO discourse_activity_pub_clients(auth_type, domain, credentials)
      SELECT #{DiscourseActivityPubClient.auth_types[:mastodon]}, key, value::json
      FROM plugin_store_rows
      WHERE plugin_name = '#{DiscourseActivityPub::PLUGIN_NAME}-oauth-app' AND value IS NOT NULL
    SQL

    add_index :discourse_activity_pub_clients,
      %i[auth_type domain],
      unique: true,
      name: "unique_activity_pub_client_auth_domains"
  end
end
