# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class AuthorizationSerializer < ActiveModel::Serializer
      attributes :actor_id
    end
  end
end
