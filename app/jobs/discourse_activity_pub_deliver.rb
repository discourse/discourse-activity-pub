# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubDeliver < ::Jobs::Base
    def execute(args)
      DiscourseActivityPub::Request.post_json_ld(uri: args[:url], body: args[:payload])
    end
  end
end