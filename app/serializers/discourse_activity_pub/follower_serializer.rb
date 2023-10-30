# frozen_string_literal: true

module DiscourseActivityPub
  class FollowerSerializer < ActiveModel::Serializer
    attributes :username,
               :local,
               :domain,
               :url,
               :followed_at,
               :icon_url,
               :user

    def user
      BasicUserSerializer.new(object.model, root: false).as_json
    end

    def followed_at
      object.follow_follows&.first.created_at
    end
  end
end
