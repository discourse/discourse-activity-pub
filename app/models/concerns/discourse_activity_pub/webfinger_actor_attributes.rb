# frozen_string_literal: true

module DiscourseActivityPub
  module WebfingerActorAttributes
    extend ActiveSupport::Concern

    def webfinger_uri
      host = self.local? ? DiscourseActivityPub.host : domain
      "#{Webfinger::ACCOUNT_SCHEME}:#{username}@#{host}"
    end

    def webfinger_aliases
      [model&.activity_pub_url]
    end

    def webfinger_links
      [webfinger_activity_link]
    end

    def webfinger_activity_link
      Webfinger.activity_link(ap_id)
    end
  end
end
