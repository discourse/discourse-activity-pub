# frozen_string_literal: true

module DiscourseActivityPub
  class Admin::LogSerializer < ActiveModel::Serializer
    attributes :id, :created_at, :level, :message, :json
  end
end
