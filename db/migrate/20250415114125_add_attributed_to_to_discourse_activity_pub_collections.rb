# frozen_string_literal: true
class AddAttributedToToDiscourseActivityPubCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_activity_pub_collections, :attributed_to_id, :string
  end
end
