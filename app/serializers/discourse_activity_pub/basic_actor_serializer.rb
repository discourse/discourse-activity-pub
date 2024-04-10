# frozen_string_literal: true

module DiscourseActivityPub
  class BasicActorSerializer < ActiveModel::Serializer
    attributes :id, :handle, :name, :model_id, :model_type, :can_admin

    def model_type
      object.model_type&.downcase
    end

    def can_admin
      scope&.can_admin?(object)
    end
  end
end
