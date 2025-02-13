# frozen_string_literal: true

module DiscourseActivityPub
  class SiteActorSerializer < ActorSerializer
    attributes :follower_count

    def follower_count
      object.followers.count
    end
  end
end
