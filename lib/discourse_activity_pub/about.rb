# frozen_string_literal: true

module DiscourseActivityPub
  class About
    include ActiveModel::Serialization

    def actors
      @actors ||= DiscourseActivityPubActor.local.active.includes(:model)
    end
  end
end
