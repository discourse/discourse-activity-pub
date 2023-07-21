# frozen_string_literal: true
class AddIconToDiscourseActivityPubActors < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_actors, :icon_url, :string
  end
end
