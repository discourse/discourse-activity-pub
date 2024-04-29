class CreateDiscourseActivityPubAuthorizations < ActiveRecord::Migration[7.0]
  def up
    create_table :discourse_activity_pub_authorizations do |t|
      t.integer :user_id, null: false
      t.integer :actor_id
      t.string :domain
      t.integer :auth_type
      t.string :token
      t.text :private_key
      t.text :public_key

      t.timestamps
    end

    add_foreign_key :discourse_activity_pub_authorizations, :users, column: :user_id

    add_foreign_key :discourse_activity_pub_authorizations,
                    :discourse_activity_pub_actors,
                    column: :actor_id

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

    authorizations = []
    DiscourseActivityPubActor
      .where(ap_id: custom_fields_by_ap_id.keys)
      .each do |actor|
        authorizations << custom_fields_by_ap_id[actor.ap_id].merge(
          actor_id: actor.id,
          auth_type: DiscourseActivityPubAuthorization.auth_types[:mastodon],
        )
      end

    DiscourseActivityPubAuthorization.insert_all(authorizations) if authorizations.present?
  end

  def down
    drop_table :discourse_activity_pub_authorizations
  end
end
