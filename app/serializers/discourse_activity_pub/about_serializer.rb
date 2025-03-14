# frozen_string_literal: true

module DiscourseActivityPub
  class AboutSerializer < ActiveModel::Serializer
    attributes :actors

    def actors
      object.actors.map do |actor|
        DiscourseActivityPub::DetailedActorSerializer.new(actor, root: false).as_json
      end
    end
  end
end
