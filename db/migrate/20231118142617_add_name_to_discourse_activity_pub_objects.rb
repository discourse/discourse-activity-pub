# frozen_string_literal: true
class AddNameToDiscourseActivityPubObjects < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_objects, :name, :string
    add_column :discourse_activity_pub_collections, :name, :string
  end
end
