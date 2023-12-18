# frozen_string_literal: true

=begin
See "7.1.2 Forwarding from Inbox": https://www.w3.org/TR/activitypub/#inbox-forwarding

We are intentionally violating the second requirement of "7.1.2 Forwarding from Inbox" by always 
forwarding public activities to the topic's remote audience, even if that audience is not included in the 
original activity's addressing. The thinking here is that reply-chain integrity, particularly for
the original topic, is more important in the context of a forum topic than it is in the context 
that 7.1.2, and "stream" implementations like Mastodon, seem to assume. Compare:
https://github.com/mastodon/mastodon/issues/5631#issuecomment-343039649

This will not forward Likes from Mastodon, as they are (intentionally) not publicly addressed
by Mastodon. See further: https://github.com/mastodon/mastodon/issues/11339
=end

module DiscourseActivityPub
  class ActivityForwarder
    attr_reader :activity

    def initialize(activity)
      @activity = activity
    end

    def perform
      return nil unless activity.cache['new'] && base_object&.ap&.object? && local_object

      forward_to = []

      if forward_to_local_followers_and_contributors?
        local_topic_actor.followers.each do |follower|
          next if follower.id == activity.stored.actor.id || forward_to.include?(follower.id)
          forward_to << follower.id
        end
        if base_object.collection
          base_object.collection.contributors(local: false).each do |contributor|
            next if contributor.id == activity.stored.actor.id || forward_to.include?(contributor.id)
            forward_to << contributor.id
          end
        end
      end

      if forward_to_remote_topic_actor?
        forward_to << remote_topic_actor.id
      end

      if forward_to.present?
        DiscourseActivityPub::DeliveryHandler.perform(
          actor: local_topic_actor,
          object: activity.stored,
          recipient_ids: forward_to,
          skip_after_scheduled: true
        )
      end
    end

    def self.perform(activity)
      new(activity).perform
    end

    protected

    def base_object
      @base_object ||= activity.stored&.base_object
    end

    def first_post_object
      @topic ||= base_object.model && base_object.model.topic.first_post.activity_pub_object
    end

    def local_object
      @local_object ||= (
        first_post_object&.local? ? first_post_object : base_object.closest_local_object
      )
    end

    def addressed_to
      @addressed_to ||= begin
        DiscourseActivityPub::JsonLd.addressed_to(activity.json).map do |address|
          DiscourseActivityPub::JsonLd.address_to_actor_id(address)
        end
      end
    end

    def publicly_addressed?
      addressed_to.include?(DiscourseActivityPub::JsonLd.public_collection_id)
    end

    def forward_to_remote_topic_actor?
      first_post_object.remote? && publicly_addressed? && remote_topic_actor
    end

    def forward_to_local_followers_and_contributors?
      addressed_to.include?(local_topic_actor&.ap_id) || (
        first_post_object.local? && publicly_addressed?
      )
    end

    def local_topic_actor
      @local_topic_actor ||= local_object&.topic_actor
    end

    def remote_topic_actor
      @remote_topic_actor ||= begin
        return nil unless first_post_object.remote?
        actor_id = DiscourseActivityPub::JsonLd.address_to_actor_id(first_post_object.audience)
        DiscourseActivityPubActor.find_by_ap_id(actor_id, local: false)
      end
    end
  end
end