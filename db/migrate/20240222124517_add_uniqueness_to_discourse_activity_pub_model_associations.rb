class AddUniquenessToDiscourseActivityPubModelAssociations < ActiveRecord::Migration[7.0]
  def change
    add_index :discourse_activity_pub_collections, %i[model_type model_id], unique: true, name: "unique_activity_pub_collection_models"
    add_index :discourse_activity_pub_actors, %i[model_type model_id], unique: true, name: "unique_activity_pub_actor_models"
    add_index :discourse_activity_pub_objects, %i[model_type model_id], unique: true, name: "unique_activity_pub_object_models"

    remove_index :discourse_activity_pub_activities, [:ap_id]
    add_index :discourse_activity_pub_activities, [:ap_id], unique: true, name: "unique_activity_pub_activities"
  end
end
