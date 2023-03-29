# frozen_string_literal: true

class DiscourseActivityPub::AP::OutboxesController < DiscourseActivityPub::AP::ActorsController
  def index
    collection = DiscourseActivityPub::AP::Collection::OrderedCollection.new(stored: @actor, collection_for: 'outbox')
    render json: DiscourseActivityPub::AP::Collection::OrderedCollectionSerializer.new(collection, root: false).as_json
  end
end