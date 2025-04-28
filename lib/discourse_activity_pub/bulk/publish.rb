# frozen_string_literal: true

module DiscourseActivityPub
  module Bulk
    class Publish
      include JsonLd

      attr_reader :actor, :topic
      attr_accessor :published_at, :result

      def initialize(actor_id: nil, topic_id: nil)
        @topic = ::Topic.find_by(id: topic_id)
        @actor = topic ? topic.activity_pub_actor : DiscourseActivityPubActor.find_by(id: actor_id)
      end

      def perform
        log_started

        return log_publish_failed("actor_not_found") if !actor
        return log_publish_failed("actor_not_ready") if !actor&.ready?
        if !DiscourseActivityPubActor::GROUP_MODELS.map(&:downcase).include?(actor.model_type.downcase)
          return log_publish_failed("actor_model_not_supported")
        end

        @published_at = Time.now.utc.iso8601(3)
        @result = PublishResult.new

        create_collections_from_topics if full_topic?
        create_actors_from_users
        create_objects_from_posts
        create_activities_from_posts
        announce_activities

        log_finished

        result.finished = true
        result
      end

      def self.perform(actor_id: nil, topic_id: nil)
        new(actor_id: actor_id, topic_id: topic_id).perform
      end

      protected

      def category_actor?
        actor.model_type.downcase == "category"
      end

      def tag_actor?
        actor.model_type.downcase == "tag"
      end

      def first_post?
        @first_post ||= actor.model.activity_pub_first_post
      end

      def full_topic?
        @full_topic ||= actor.model.activity_pub_full_topic
      end

      def create_collections_from_topics
        topics = ::Topic

        if category_actor?
          topics =
            topics
              .where("topics.category_id = ?", actor.model.id)
              .where.not("topics.id = ?", actor.model.topic_id.to_i)
        end

        if tag_actor?
          topics =
            topics.where(
              "topics.id IN (SELECT topic_id FROM topic_tags WHERE topic_tags.tag_id = ?)",
              actor.model.id,
            )
        end

        topics = topics.where("topics.id = ?", topic.id) if topic

        topics =
          topics
            .joins(
              "LEFT JOIN discourse_activity_pub_collections c ON c.model_type = 'Topic' AND topics.id = c.model_id",
            )
            .where("c.id IS NULL OR c.published_at IS NULL")
            .distinct

        if topics.any?
          collections = build_collections(topics)
          create_collections(collections)
        end
      end

      def create_actors_from_users
        users = ::User.real.joins(posts: :topic)

        if category_actor?
          users =
            users
              .where("topics.category_id = ?", actor.model.id)
              .where.not("topics.id = ?", actor.model.topic_id.to_i)
        end

        if tag_actor?
          users =
            users.where(
              "topics.id IN (SELECT topic_id FROM topic_tags WHERE topic_tags.tag_id = ?)",
              actor.model.id,
            )
        end

        users = users.where("topics.id = ?", topic.id) if topic
        users = users.where("posts.post_number = 1") if first_post?

        users =
          users
            .joins(
              "LEFT JOIN discourse_activity_pub_actors a ON a.model_type = 'User' AND users.id = a.model_id",
            )
            .where("a.id IS NULL")
            .distinct

        if users.any?
          actors = build_actors(users)
          create_actors(actors)
        end
      end

      def create_objects_from_posts
        posts = ::Post.joins(:topic)

        if category_actor?
          posts =
            posts
              .where("topics.category_id = ?", actor.model.id)
              .where.not("topics.id = ?", actor.model.topic_id.to_i)
        end

        if tag_actor?
          posts =
            posts.where(
              "topics.id IN (SELECT topic_id FROM topic_tags WHERE topic_tags.tag_id = ?)",
              actor.model.id,
            )
        end

        posts = posts.where("topics.id = ?", topic.id) if topic
        posts = posts.where("posts.post_number = 1") if first_post?

        posts =
          posts
            .joins(
              "LEFT JOIN discourse_activity_pub_objects o ON o.model_type = 'Post' AND posts.id = o.model_id",
            )
            .where("o.id IS NULL OR o.published_at IS NULL")
            .distinct
            .order("posts.topic_id, posts.post_number")

        if posts.any?
          objects, post_custom_fields = build_objects_and_post_custom_fields(posts)
          ::PostCustomField.upsert_all(post_custom_fields) if post_custom_fields.any?
          create_objects(objects)
        end
      end

      def create_activities_from_posts
        posts = ::Post.joins(:topic)

        if category_actor?
          posts =
            posts
              .where("topics.category_id = ?", actor.model.id)
              .where.not("topics.id = ?", actor.model.topic_id.to_i)
        end

        if tag_actor?
          posts =
            posts.where(
              "topics.id IN (SELECT topic_id FROM topic_tags WHERE topic_tags.tag_id = ?)",
              actor.model.id,
            )
        end

        posts = posts.where("topics.id = ?", topic.id) if topic
        posts = posts.where("posts.post_number = 1") if first_post?

        posts =
          posts.includes(:activity_pub_object).distinct.order("posts.topic_id, posts.post_number")

        if posts.any?
          activities = build_activities(posts)
          create_activities(activities)
        end
      end

      def announce_activities
        activities =
          DiscourseActivityPubActivity
            .joins(
              "JOIN discourse_activity_pub_objects o ON discourse_activity_pub_activities.object_id = o.id AND discourse_activity_pub_activities.object_type = 'DiscourseActivityPubObject'",
            )
            .joins("JOIN posts ON o.model_type = 'Post' AND o.model_id = posts.id")
            .joins("JOIN topics ON topics.id = posts.topic_id")

        if category_actor?
          activities =
            activities
              .where("topics.category_id = ?", actor.model.id)
              .where.not("topics.id = ?", actor.model.topic_id.to_i)
        end

        if tag_actor?
          activities =
            activities.where(
              "topics.id IN (SELECT topic_id FROM topic_tags WHERE topic_tags.tag_id = ?)",
              actor.model.id,
            )
        end

        activities = activities.where("topics.id = ?", topic.id) if topic
        activities = activities.where("posts.post_number = 1") if first_post?

        activities = activities.distinct

        if activities.any?
          announcements = build_announcements(activities)
          create_announcements(announcements)
        end
      end

      def build_collections(topics)
        topics.map do |topic|
          base_attrs(
            object: topic.activity_pub_object,
            base_type: AP::Collection.type,
            type: AP::Collection::OrderedCollection.type,
          ).merge(name: topic.title, model_id: topic.id, model_type: "Topic")
        end
      end

      def build_actors(users)
        users.map do |user|
          base_attrs(
            object: user.activity_pub_actor,
            base_type: AP::Actor.type,
            type: AP::Actor::Person.type,
          ).merge(username: user.username, name: user.name, model_id: user.id, model_type: "User")
        end
      end

      def build_objects_and_post_custom_fields(posts)
        objects = []
        post_custom_fields = []
        post_number_id_map = {}

        posts.each do |post|
          next unless post.activity_pub_actor
          next if post.activity_pub_object&.published_at

          increment_published_at

          object =
            base_attrs(
              object: post.activity_pub_object,
              base_type: AP::Object.type,
              type: post.activity_pub_default_object_type,
            ).merge(
              content: post.activity_pub_content,
              name: post.activity_pub_name,
              model_id: post.id,
              model_type: "Post",
              reply_to_id: nil,
              collection_id: nil,
              attributed_to_id: nil,
            )

          if !post.is_first_post?
            object[:reply_to_id] = post_number_id_map.dig(
              post.topic_id,
              post.reply_to_post_number,
            ) || post_number_id_map.dig(post.topic_id, 1) ||
              post.activity_pub_reply_to_object&.ap_id
          end

          if full_topic?
            object[:collection_id] = post.topic.activity_pub_object.id
            object[:attributed_to_id] = post.activity_pub_actor.ap_id
          end

          objects << object

          post_custom_fields << {
            post_id: post.id,
            name: "activity_pub_content",
            value: object[:content],
          }
          post_custom_fields << {
            post_id: post.id,
            name: "activity_pub_visibility",
            value: post.activity_pub_visibility_on_create,
          }
          post_custom_fields << {
            post_id: post.id,
            name: "activity_pub_published_at",
            value: published_at,
          }

          post_number_id_map[post.topic_id] ||= {}
          post_number_id_map[post.topic_id][post.post_number] = object[:ap_id]
        end

        [objects, post_custom_fields]
      end

      def build_activities(posts)
        activities = []

        posts.each do |post|
          actor = post.user.activity_pub_actor
          object = post.activity_pub_object
          next unless actor && object

          activity =
            (
              if object.activities.present?
                object.activities.where(ap_type: AP::Activity::Create.type).first
              else
                nil
              end
            )

          next if activity&.published_at
          increment_published_at

          activities << base_attrs(
            object: activity,
            base_type: AP::Activity.type,
            type: AP::Activity::Create.type,
          ).merge(
            actor_id: actor.id,
            object_id: object.id,
            object_type: object.class.name,
            visibility:
              DiscourseActivityPubActivity.visibilities[
                object.model.activity_pub_visibility.to_sym
              ],
          )
        end

        activities
      end

      def build_announcements(activities)
        activities
          .where.not(ap_type: DiscourseActivityPub::AP::Activity::Announce.type)
          .where
          .missing(:announcement)
          .map do |activity|
            base_attrs(base_type: AP::Activity.type, type: AP::Activity::Announce.type).merge(
              actor_id: actor.id,
              object_id: activity.id,
              object_type: activity.class.name,
              visibility: DiscourseActivityPubActivity.visibilities[:public],
            )
          end
      end

      def create_collections(collections)
        return if collections.blank?

        stored =
          DiscourseActivityPubCollection.upsert_all(
            collections,
            unique_by: %i[model_type model_id],
            returning: Arel.sql("ap_id, (xmax = '0') as inserted"),
          )
        log_stored(stored, "collections")
        result.collections = stored.map { |r| r["ap_id"] }
      end

      def create_actors(actors)
        return if actors.blank?

        stored =
          DiscourseActivityPubActor.upsert_all(
            actors,
            unique_by: %i[model_type model_id],
            returning: Arel.sql("ap_id, (xmax = '0') as inserted"),
          )
        log_stored(stored, "actors")
        result.actors = stored.map { |r| r["ap_id"] }
      end

      def create_objects(objects)
        return if objects.blank?

        stored =
          result.objects =
            DiscourseActivityPubObject.upsert_all(
              objects,
              unique_by: %i[model_type model_id],
              returning: Arel.sql("ap_id, (xmax = '0') as inserted"),
            )
        log_stored(stored, "objects")
        result.objects = stored.map { |r| r["ap_id"] }
      end

      def create_activities(activities)
        return if activities.blank?

        stored =
          DiscourseActivityPubActivity.upsert_all(
            activities,
            unique_by: %i[ap_id],
            returning: Arel.sql("ap_id, (xmax = '0') as inserted"),
          )
        log_stored(stored, "activities")
        result.activities = stored.map { |r| r["ap_id"] }
      end

      def create_announcements(announcements)
        return if announcements.blank?

        stored = DiscourseActivityPubActivity.upsert_all(announcements, returning: %i[ap_id])
        result.announcements = stored.map { |r| r["ap_id"] }
      end

      def base_attrs(object: nil, base_type: nil, type: nil)
        attrs = { local: true }
        if object.present?
          attrs[:ap_key] = object.ap_key
          attrs[:ap_id] = object.ap_id
          attrs[:ap_type] = object.ap_type
        else
          attrs[:ap_key] = generate_key
          attrs[:ap_id] = json_ld_id(base_type, attrs[:ap_key])
          attrs[:ap_type] = type
          attrs[:created_at] = published_at
        end
        attrs[:published_at] = published_at unless base_type == AP::Actor.type
        attrs
      end

      def increment_published_at
        @published_at = (@published_at.to_time + 1 / 1000.0).iso8601(3)
      end

      def log_target
        @log_target ||= topic ? topic.title : actor.handle
      end

      def log_publish_failed(key)
        message =
          I18n.t(
            "discourse_activity_pub.bulk.publish.warning.publish_did_not_start",
            target: log_target,
          )
        message +=
          ": " + I18n.t("discourse_activity_pub.bulk.publish.warning.#{key}", target: log_target)
        DiscourseActivityPub::Logger.warn(message)
      end

      def log_started
        DiscourseActivityPub::Logger.info(
          I18n.t("discourse_activity_pub.bulk.publish.info.started", target: log_target),
        )
      end

      def log_finished
        DiscourseActivityPub::Logger.info(
          I18n.t("discourse_activity_pub.bulk.publish.info.finished", target: log_target),
        )
      end

      def log_stored(stored, type)
        created = 0
        updated = 0
        stored.each do |row|
          if row["inserted"]
            created += 1
          else
            updated += 1
          end
        end
        log("created", type, created) if created > 0
        log("updated", type, updated) if updated > 0
      end

      def log(action, type, count)
        DiscourseActivityPub::Logger.info(
          I18n.t("discourse_activity_pub.bulk.publish.info.#{action}_#{type}", count: count),
        )
      end
    end
  end
end
