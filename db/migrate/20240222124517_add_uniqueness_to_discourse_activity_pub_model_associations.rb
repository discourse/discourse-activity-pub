# frozen_string_literal: true
class AddUniquenessToDiscourseActivityPubModelAssociations < ActiveRecord::Migration[7.0]
  def up
    remove_index :discourse_activity_pub_activities, %i[ap_id]
    remove_index :discourse_activity_pub_collections, %i[ap_id]
    remove_index :discourse_activity_pub_actors, %i[ap_id]
    remove_index :discourse_activity_pub_objects, %i[ap_id]

    # Remove duplicates
    execute "DELETE FROM discourse_activity_pub_actors WHERE id IN (SELECT id FROM (SELECT id, row_number() over (PARTITION BY ap_id ORDER BY model_id IS NULL, model_id DESC) AS rnum FROM discourse_activity_pub_actors) t WHERE t.rnum > 1)"
    execute "DELETE FROM discourse_activity_pub_activities WHERE id IN (SELECT id FROM (SELECT id, row_number() over (PARTITION BY ap_id ORDER BY object_id IS NULL, object_id DESC) AS rnum FROM discourse_activity_pub_activities) t WHERE t.rnum > 1)"
    execute "DELETE FROM discourse_activity_pub_collections WHERE id IN (SELECT id FROM (SELECT id, row_number() over (PARTITION BY ap_id ORDER BY model_id IS NULL, model_id DESC) AS rnum FROM discourse_activity_pub_collections) t WHERE t.rnum > 1)"
    execute "DELETE FROM discourse_activity_pub_objects WHERE id IN (SELECT id FROM (SELECT id, row_number() over (PARTITION BY ap_id ORDER BY model_id IS NULL, model_id DESC) AS rnum FROM discourse_activity_pub_objects) t WHERE t.rnum > 1)"

    add_index :discourse_activity_pub_actors, %i[ap_id], unique: true
    add_index :discourse_activity_pub_collections, %i[ap_id], unique: true
    add_index :discourse_activity_pub_activities, %i[ap_id], unique: true
    add_index :discourse_activity_pub_objects, %i[ap_id], unique: true
    add_index :discourse_activity_pub_collections,
              %i[model_type model_id],
              unique: true,
              name: "unique_activity_pub_collection_models"
    add_index :discourse_activity_pub_actors,
              %i[model_type model_id],
              unique: true,
              name: "unique_activity_pub_actor_models"
    add_index :discourse_activity_pub_objects,
              %i[model_type model_id],
              unique: true,
              name: "unique_activity_pub_object_models"
  end

  def down
    remove_index :discourse_activity_pub_actors, %i[ap_id]
    remove_index :discourse_activity_pub_collections, %i[ap_id]
    remove_index :discourse_activity_pub_activities, %i[ap_id]
    remove_index :discourse_activity_pub_objects, %i[ap_id]
    remove_index :discourse_activity_pub_collections,
                 %i[model_type model_id],
                 name: "unique_activity_pub_collection_models"
    remove_index :discourse_activity_pub_actors,
                 %i[model_type model_id],
                 name: "unique_activity_pub_actor_models"
    remove_index :discourse_activity_pub_objects,
                 %i[model_type model_id],
                 name: "unique_activity_pub_object_models"
    add_index :discourse_activity_pub_activities, %i[ap_id]
    add_index :discourse_activity_pub_collections, %i[ap_id]
    add_index :discourse_activity_pub_actors, %i[ap_id]
    add_index :discourse_activity_pub_objects, %i[ap_id]
  end
end
