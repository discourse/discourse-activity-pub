# frozen_string_literal: true

module DiscourseActivityPub
  class AuthorizationSerializer < ActiveModel::Serializer
    attributes :id, :user_id, :auth_type

    has_one :actor, serializer: BasicActorSerializer, embed: :objects

    def auth_type
      DiscourseActivityPubAuthorization.auth_types[object.auth_type].to_s
    end
  end
end
