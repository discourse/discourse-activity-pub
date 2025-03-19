# frozen_string_literal: true

module DiscourseActivityPub
  class AboutSerializer < ActiveModel::Serializer
    attributes :category_actors, :tag_actors

    def category_actors
      object.category_actors.map do |actor|
        DiscourseActivityPub::CardActorSerializer.new(actor, root: false).as_json
      end
    end

    def tag_actors
      object.tag_actors.map do |actor|
        DiscourseActivityPub::CardActorSerializer.new(actor, root: false).as_json
      end
    end
  end
end
