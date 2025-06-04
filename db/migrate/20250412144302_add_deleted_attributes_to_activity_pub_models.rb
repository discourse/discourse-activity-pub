# frozen_string_literal: true
class AddDeletedAttributesToActivityPubModels < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_activity_pub_actors, :deleted_at, :datetime
    add_column :discourse_activity_pub_actors, :ap_former_type, :string
    add_column :discourse_activity_pub_objects, :deleted_at, :datetime
    add_column :discourse_activity_pub_objects, :ap_former_type, :string
    add_column :discourse_activity_pub_collections, :deleted_at, :datetime
    add_column :discourse_activity_pub_collections, :ap_former_type, :string
  end
end
