# frozen_string_literal: true

module DiscourseActivityPub
  class AuthorizationSerializer < ActiveModel::Serializer
    attributes :id, :user_id, :auth_type

    has_one :actor, serializer: ActorSerializer, embed: :objects

    def auth_type
      DiscourseActivityPubClient.auth_types[object.client.auth_type].to_s
    end
  end
end
