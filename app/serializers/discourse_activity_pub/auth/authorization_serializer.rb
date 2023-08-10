# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class AuthorizationSerializer < ActiveModel::Serializer
      attributes :domain,
                 :access
    end
  end
end