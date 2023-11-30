# frozen_string_literal: true

module DiscourseActivityPub
  class WebfingerSerializer < ActiveModel::Serializer
    attributes :subject, :aliases, :links

    def subject
      object.webfinger_uri
    end

    def aliases
      object.webfinger_aliases
    end

    def links
      object.webfinger_links
    end
  end
end
