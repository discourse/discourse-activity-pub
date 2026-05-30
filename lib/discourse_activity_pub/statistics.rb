# frozen_string_literal: true
module DiscourseActivityPub
  module Statistics
    # https://github.com/jhass/nodeinfo/blob/main/schemas/2.2/schema.json#usage
    def nodeinfo
      {
        users_total: active_users.count,
        users_seen_half_year: active_users.where("last_seen_at > ?", 180.days.ago).count,
        users_seen_month: active_users.where("last_seen_at > ?", 30.days.ago).count,
        posts_local: local_posts.where("reply_to_post_number IS NULL").count,
        replies_local: local_posts.where("reply_to_post_number IS NOT NULL").count,
      }
    end

    def active_users
      valid_users.where("staged IS FALSE")
    end

    def local_posts
      ::Post.where("user_id NOT IN (SELECT id FROM users WHERE staged IS TRUE)")
    end
  end
end
