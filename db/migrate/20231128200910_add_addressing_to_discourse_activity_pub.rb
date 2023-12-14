# frozen_string_literal: true
class AddAddressingToDiscourseActivityPub < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_collections, :audience, :string
    add_column :discourse_activity_pub_objects, :audience, :string
    add_column :discourse_activity_pub_objects, :context, :string
    add_column :discourse_activity_pub_objects, :target, :string
  end
end
