# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubDeliver < ::Jobs::Base
    def execute(args)
      DiscourseActivityPub::Request.post_json_ld(actor_id: args[:actor_id], uri: args[:uri], body: args[:payload])
    end
  end
end