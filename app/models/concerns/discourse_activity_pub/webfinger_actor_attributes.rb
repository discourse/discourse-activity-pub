# frozen_string_literal: true

module DiscourseActivityPub
  module WebfingerActorAttributes
    extend ActiveSupport::Concern

    def webfinger_uri
      "#{Webfinger::ACCOUNT_SCHEME}:#{preferred_username}@#{domain}"
    end

    def webfinger_aliases
      [model.full_url]
    end

    def webfinger_links
      [webfinger_activity_link]
    end

    def webfinger_activity_link
      Webfinger.activity_link(uid)
    end
  end
end