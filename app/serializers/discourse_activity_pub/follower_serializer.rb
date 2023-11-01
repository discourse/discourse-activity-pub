# frozen_string_literal: true

module DiscourseActivityPub
  class FollowerSerializer < ActiveModel::Serializer
    attributes :name,
               :username,
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
      object.follow_follows&.first.followed_at
    end
  end
end
