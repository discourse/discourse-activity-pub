# frozen_string_literal: true
class AddSharedInboxToDiscourseActivityPubActors < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_activity_pub_actors, :shared_inbox, :string
  end
end
