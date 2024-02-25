# frozen_string_literal: true

module DiscourseActivityPub
  module Bulk
    class Publish
      include JsonLd

      attr_reader :actor
      attr_accessor :published_at,
                    :result

      SUPPORTED_MODEL_TYPES = %w[category]

      def initialize(actor_id: nil)
        @actor = DiscourseActivityPubActor.find_by(id: actor_id)
      end

      def perform
        return log_publish_failed("actor_not_ready") if !actor&.ready?
        model_type = actor.model_type.downcase
        return log_publish_failed("actor_model_not_supported") if !SUPPORTED_MODEL_TYPES.include?(model_type)

        log_publish_started

        @published_at = Time.now.utc.iso8601
        @result = PublishResult.new

        self.send("publish_#{model_type}")

        log_publish_finished

        result
      end

      def self.perform(actor_id: nil)
        new(actor_id: actor_id).perform
      end

      protected

      def publish_category
        if actor.model.activity_pub_full_topic
          topics = Topic
            .where("topics.category_id = ?", actor.model.id)
            .where.not("topics.id = ?", actor.model.topic_id.to_i)
            .joins("LEFT JOIN discourse_activity_pub_collections c ON c.model_type = 'Topic' AND topics.id = c.model_id")
            .where("c.id IS NULL OR c.published_at IS NULL")
            .distinct

          if topics.any?
            create_collections(topics)
          end
        end

        users = User.real
          .joins(posts: :topic)
          .where("topics.category_id = ?", actor.model.id)
          .where.not("topics.id = ?", actor.model.topic_id.to_i)
          .joins("LEFT JOIN discourse_activity_pub_actors a ON a.model_type = 'User' AND users.id = a.model_id")
          .where("a.id IS NULL")
          .distinct

        if actor.model.activity_pub_first_post
          users = users.where("posts.post_number = 1")
        end

        if users.any?
          create_actors(users)
        end

        posts = Post
          .joins(:topic)
          .where("topics.category_id = ?", actor.model.id)
          .where.not("topics.id = ?", actor.model.topic_id.to_i)
          .joins("LEFT JOIN discourse_activity_pub_objects o ON o.model_type = 'Post' AND posts.id = o.model_id")
          .where("o.id IS NULL OR o.published_at IS NULL")
          .distinct
          .order("posts.topic_id, posts.post_number")

        if actor.model.activity_pub_first_post
          posts = posts.where("posts.post_number = 1")
        end

        if posts.any?
          create_objects(posts)
        end

        objects = DiscourseActivityPubObject
          .joins("JOIN posts ON discourse_activity_pub_objects.model_type = 'Post' AND discourse_activity_pub_objects.model_id = posts.id")
          .joins("JOIN topics ON topics.id = posts.topic_id")
          .where("topics.category_id = ?", actor.model.id)
          .where.not("topics.id = ?", actor.model.topic_id.to_i)
          .distinct

        if objects.any?
          create_activities(objects)
        end

        activities = DiscourseActivityPubActivity
          .joins("JOIN discourse_activity_pub_objects o ON discourse_activity_pub_activities.object_id = o.id AND discourse_activity_pub_activities.object_type = 'DiscourseActivityPubObject'")
          .joins("JOIN posts ON o.model_type = 'Post' AND o.model_id = posts.id")
          .joins("JOIN topics ON topics.id = posts.topic_id")
          .where("topics.category_id = ?", actor.model.id)
          .where.not("topics.id = ?", actor.model.topic_id.to_i)
          .distinct

        if actor.model.activity_pub_first_post
          activities = activities.where("posts.post_number = 1")
        end

        announce_activities(activities)

        result.finished = true
      end

      def create_collections(topics)
        collections = topics.map do |topic|
          base_attrs(
            object: topic.activity_pub_object,
            base_type: AP::Collection.type,
            type: AP::Collection::OrderedCollection.type
          ).merge(
            name: topic.title,
            model_id: topic.id,
            model_type: 'Topic'
          )
        end

        result.collections = DiscourseActivityPubCollection.upsert_all(
          collections,
          unique_by: %i[model_type model_id],
          returning: %i[ap_id]
        )
      end

      def create_actors(users)
        actors = users.map do |user|
          base_attrs(
            object: user.activity_pub_actor,
            base_type: AP::Actor.type,
            type: AP::Actor::Person.type
          ).merge(
            username: user.username,
            name: user.name,
            model_id: user.id,
            model_type: 'User'
          )
        end

        result.actors = DiscourseActivityPubActor.upsert_all(
          actors,
          unique_by: %i[model_type model_id],
          returning: %i[ap_id]
        )
      end

      def create_objects(posts)
        objects = []
        post_custom_fields = []
        post_number_id_map = {}

        posts.each do |post|
          next unless post.activity_pub_actor
          next if post.activity_pub_object&.published_at

          object = base_attrs(
            object: post.activity_pub_object,
            base_type: AP::Object.type,
            type: post.activity_pub_default_object_type
          ).merge(
            content: post.activity_pub_content,
            name: post.activity_pub_name,
            model_id: post.id,
            model_type: 'Post',
            reply_to_id: nil,
            collection_id: nil,
            attributed_to_id: nil
          )

          if !post.activity_pub_is_first_post?
            object[:reply_to_id] =
              post_number_id_map.dig(post.topic_id, post.reply_to_post_number) ||
              post_number_id_map.dig(post.topic_id, 1) ||
              post.activity_pub_reply_to_object&.ap_id
          end

          if actor.model.activity_pub_full_topic
            object[:collection_id] = post.topic.activity_pub_object.id
            object[:attributed_to_id] = post.activity_pub_actor.ap_id
          end

          objects << object

          post_custom_fields << {
            post_id: post.id,
            name: "activity_pub_content",
            value: object[:content]
          }
          post_custom_fields << {
            post_id: post.id,
            name: "activity_pub_visibility",
            value: post.activity_pub_visibility_on_create
          }
          post_custom_fields << {
            post_id: post.id,
            name: "activity_pub_published_at",
            value: published_at
          }

          post_number_id_map[post.topic_id] ||= {}
          post_number_id_map[post.topic_id][post.post_number] = object[:ap_id]
        end

        PostCustomField.upsert_all(post_custom_fields)
        result.objects = DiscourseActivityPubObject.upsert_all(
          objects,
          unique_by: %i[model_type model_id],
          returning: %i[ap_id]
        )
      end

      def create_activities(objects)        
        activities = []

        objects.each do |object|
          activity = object.activities.present? ?
            object.activities.where(
              ap_type: AP::Activity::Create.type
            ).first : nil

          next if activity&.published_at

          activities << base_attrs(
            object: activity,
            base_type: AP::Activity.type,
            type: AP::Activity::Create.type
          ).merge(
            actor_id: object.model.user.activity_pub_actor.id,
            object_id: object.id,
            object_type: object.class.name,
            visibility: DiscourseActivityPubActivity.visibilities[
              object.model.activity_pub_visibility.to_sym
            ]
          )
        end

        result.activities = DiscourseActivityPubActivity.upsert_all(
          activities,
          unique_by: %i[ap_id],
          returning: %i[ap_id]
        )
      end

      def announce_activities(activities)
        announcements = activities
          .where.not(ap_type: DiscourseActivityPub::AP::Activity::Announce.type)
          .where.missing(:announcement)
          .map do |activity|
            base_attrs(
              base_type: AP::Activity.type,
              type: AP::Activity::Announce.type
            ).merge(
              actor_id: actor.id,
              object_id: activity.id,
              object_type: activity.class.name,
              visibility: DiscourseActivityPubActivity.visibilities[:public]
            )
          end

        result.announcements = DiscourseActivityPubActivity.upsert_all(
          announcements,
          returning: %i[ap_id]
        )
      end

      def base_attrs(object: nil, base_type: nil, type: nil)
        attrs = {
          local: true
        }
        if object.present?
          attrs[:ap_key] = object.ap_key
          attrs[:ap_id] = object.ap_id
          attrs[:ap_type] = object.ap_type
        else
          attrs[:ap_key] = generate_key
          attrs[:ap_id] = json_ld_id(base_type, attrs[:ap_key])
          attrs[:ap_type] = type
        end
        attrs[:published_at] = published_at unless base_type == AP::Actor.type
        attrs
      end

      def log_publish_failed(key)
        message =
          I18n.t(
            "discourse_activity_pub.publish.warning.publish_did_not_start",
            actor: actor.handle
          )
        message +=
          ": " +
            I18n.t(
              "discourse_activity_pub.publish.warning.#{key}",
              actor: actor.handle
            )
        DiscourseActivityPub::Logger.warn(message)
      end

      def log_publish_started
        DiscourseActivityPub::Logger.info(
          I18n.t(
            "discourse_activity_pub.publish.info.publish_started",
            actor: actor.handle
          ),
        )
      end

      def log_publish_finished
        DiscourseActivityPub::Logger.info(
          I18n.t(
            "discourse_activity_pub.publish.info.publish_finished",
            actor: actor.handle,
            activities_count: result.activities.count,
          ),
        )
      end
    end
  end
end