# frozen_string_literal: true

module DiscourseActivityPub
  class BasicActorSerializer < ActiveModel::Serializer
    attributes :id, :username, :domain, :handle, :ap_id

    def handle
      DiscourseActivityPub::Webfinger::Handle.new(
        username: object.username,
        domain: object.domain || DiscourseActivityPub.host,
      ).to_s
    end
  end
end
