# frozen_string_literal: true
class AddIndexToDiscourseActivityPubActorsApKey < ActiveRecord::Migration[7.2]
  def change
    add_index :discourse_activity_pub_actors, :ap_key, unique: true
  end
end
