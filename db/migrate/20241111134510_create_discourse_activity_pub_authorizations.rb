# frozen_string_literal: true
class CreateDiscourseActivityPubAuthorizations < ActiveRecord::Migration[7.1]
  def up
    create_table :discourse_activity_pub_authorizations do |t|
      t.integer :user_id, null: false
      t.bigint :actor_id
      t.bigint :client_id
      t.string :token, limit: 1000

      t.timestamps
    end

    add_index :discourse_activity_pub_authorizations,
              %i[user_id actor_id],
              unique: true,
              name: "unique_activity_pub_authorization_user_actors"

    users =
      User.joins("INNER JOIN user_custom_fields ucf ON ucf.user_id = users.id").where(
        "ucf.name = 'activity_pub_actor_ids' AND ucf.id IS NOT NULL",
      )

    custom_fields_by_ap_id =
      users.each_with_object({}) do |user, result|
        if user.custom_fields["activity_pub_actor_ids"].present?
          actor_ids = JSON.parse(user.custom_fields["activity_pub_actor_ids"])
          access_tokens = JSON.parse(user.custom_fields["activity_pub_access_tokens"])
          actor_ids.each do |actor_ap_id, domain|
            result[actor_ap_id] = { user_id: user.id, domain: domain, token: access_tokens[domain] }
          end
        end
      end

    clients_by_domain =
      DiscourseActivityPubClient
        .where(auth_type: DiscourseActivityPubClient.auth_types[:mastodon])
        .index_by { |client| client.domain }

    authorizations =
      DiscourseActivityPubActor
        .where(ap_id: custom_fields_by_ap_id.keys)
        .each_with_object([]) do |actor, result|
          attrs = custom_fields_by_ap_id[actor.ap_id]
          client = clients_by_domain[attrs.delete(:domain)]
          result << attrs.merge(actor_id: actor.id, client_id: client.id)
        end

    DiscourseActivityPubAuthorization.insert_all(authorizations) if authorizations.present?
  end

  def down
    drop_table :discourse_activity_pub_authorizations
  end
end
