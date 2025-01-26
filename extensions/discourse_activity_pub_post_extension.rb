# frozen_string_literal: true
module DiscourseActivityPubPostExtension
  def reload
    @activity_pub_taxonomy_actors = nil
    @activity_pub_taxonomy_followers = nil
    super
  end

  def activity_pub_taxonomy_actors
    @activity_pub_taxonomy_actors ||=
      begin
        if !@destroyed_post_activity_pub_taxonomy_actors.nil?
          return @destroyed_post_activity_pub_taxonomy_actors
        end
        activity_pub_topic.activity_pub_taxonomies.map { |taxonomy| taxonomy.activity_pub_actor }
      end
  end

  def activity_pub_taxonomy_followers
    @activity_pub_taxonomy_followers ||=
      activity_pub_taxonomy_actors.reduce([]) do |result, actor|
        actor.followers.each { |follower| result << follower }
        result
      end
  end
end
