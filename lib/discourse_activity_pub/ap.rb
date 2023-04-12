# frozen_string_literal: true

=begin
AP is the interface between Discourse and ActivityPub. All incoming ActivityPub content
is first handled by AP, see app/controllers/discourse_activity_pub/ap/*. All outgoing
ActivityPub content is modelled and serialized by AP. See lib/discourse_activity_pub/ap/*
and app/serializers/discourse_activity_pub/ap/*. The AP class structure reflects
the data model in https://www.w3.org/TR/activitypub and related specifications.
=end

module DiscourseActivityPub
  module AP
  end
end