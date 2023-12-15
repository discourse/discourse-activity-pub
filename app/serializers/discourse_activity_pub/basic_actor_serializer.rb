# frozen_string_literal: true

module DiscourseActivityPub
  class BasicActorSerializer < ActiveModel::Serializer
    attributes :id, :handle, :name
  end
end
