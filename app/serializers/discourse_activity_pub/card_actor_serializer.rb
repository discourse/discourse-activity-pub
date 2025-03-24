# frozen_string_literal: true

module DiscourseActivityPub
  class CardActorSerializer < DetailedActorSerializer
    attributes :follower_count

    def follower_count
      object.followers.count
    end
  end
end
