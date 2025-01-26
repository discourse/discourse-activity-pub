# frozen_string_literal: true

module DiscourseActivityPub
  class SiteActorSerializer < BasicActorSerializer
    attributes :follower_count

    def follower_count
      object.followers.count
    end
  end
end
