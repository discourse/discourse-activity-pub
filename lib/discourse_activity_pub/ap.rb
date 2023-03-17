# frozen_string_literal: true

=begin
AP is the interface between Discourse and ActivityPub. All incoming ActivityPub content
is first handled by AP, starting with app/controllers/discourse_activity_pub/ap/*.
All outgoing ActivityPub content is serialized and sent by AP. See lib/discourse_activity_pub/ap/*
and app/serializers/discourse_activity_pub/ap/*. The AP class structure reflects
the data model in https://www.w3.org/TR/activitypub and dependent specifications.
=end

module DiscourseActivityPub
  module AP
  end
end