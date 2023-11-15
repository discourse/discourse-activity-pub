# frozen_string_literal: true

module DiscourseActivityPub
  class BasicActorSerializer < ActiveModel::Serializer
    attributes :id,
                :username
  end
end
