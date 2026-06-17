# frozen_string_literal: true

class DiscourseActivityPub::AP::CollectionsController < DiscourseActivityPub::AP::ObjectsController
  requires_plugin DiscourseActivityPub::PLUGIN_NAME

  before_action :ensure_collection_exists
  before_action :ensure_can_access_collection

  def show
    render_activity_json(collection_json)
  end

  protected

  def collection_json
    collection = @collection.ap
    collection.items = collection.items.select { |item| can_see_collection_item?(item) }
    collection_serializer(collection).new(collection, root: false).as_json.with_indifferent_access
  end

  def collection_serializer(collection)
    "#{collection.class.name}Serializer".constantize
  end

  def can_see_collection_item?(item)
    model = collection_item_model(item)
    model.blank? || guardian.can_see?(model)
  end

  def collection_item_model(item)
    stored = item.stored
    stored = stored.base_object if stored.respond_to?(:base_object)
    stored.model if stored.respond_to?(:model)
  end

  def ensure_collection_exists
    unless @collection = DiscourseActivityPubCollection.find_by(ap_key: params[:key], local: true)
      render_activity_pub_error("not_found", 404)
    end
  end

  def ensure_can_access_collection
    render_activity_pub_error("not_available", 401) unless guardian.can_see?(@collection.model)
  end
end
