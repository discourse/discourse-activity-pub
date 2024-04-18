# frozen_string_literal: true

module DiscourseActivityPub
  module Bulk
    class Process
      include JsonLd

      DEFAULT_MAX_ITEMS = 1000

      attr_reader :actor,
                  :target_actor,
                  :collection_to_process,
                  :remote_collections_by_ap_id,
                  :created_topics_count,
                  :created_replies_count,
                  :result

      def initialize(actor_id: nil, target_actor_id: nil)
        @actor = DiscourseActivityPubActor.find_by(id: actor_id)
        @target_actor = DiscourseActivityPubActor.find_by(id: target_actor_id)
        @result = ProcessResult.new
      end

      def perform
        return log_process_failed("actors_not_ready") if !actor&.ready? || !target_actor&.ready?
        return log_process_failed("not_following_target") if !actor.following?(target_actor)

        response = DiscourseActivityPub::Request.get_json_ld(uri: target_actor.outbox)
        return log_process_failed("outbox_response_invalid") unless response

        @collection_to_process = DiscourseActivityPub::AP::Object.factory(response)
        unless collection_to_process&.type ==
                 DiscourseActivityPub::AP::Collection::OrderedCollection.type
          return log_process_failed("outbox_response_invalid")
        end

        process_collection

        log_process("started")

        process_users
        process_posts

        log_process("finished")

        result.finished = true
        result
      end

      def self.perform(actor_id: nil, target_actor_id: nil)
        new(actor_id: actor_id, target_actor_id: target_actor_id).perform
      end

      protected

      def process_collection
        result.activities_by_ap_id = {}

        create_activities = []
        update_activities = []
        delete_activities = []

        collection_to_process.resolve_items_to_process
        return unless collection_to_process.items_to_process.present?

        collection_to_process.items_to_process.each do |item, result|
          item = item["object"] if item["type"] == AP::Activity::Announce.type

          activity = DiscourseActivityPub::AP::Activity.factory(item)
          next unless activity.present?

          create_activities << activity if activity.create?
          update_activities << activity if activity.update?
          delete_activities << activity if activity.delete?
        end

        deleted_object_ids =
          delete_activities.map { |activity| resolve_id(activity.json["object"]) }
        updated_object_map =
          update_activities.each_with_object({}) do |activity, result|
            result[resolve_id(activity.json["object"])] = activity.json["object"]
          end

        # Remove deleted
        create_activities =
          create_activities.each_with_object([]) do |activity, result|
            unless deleted_object_ids.include?(resolve_id(activity.json["object"]))
              result << activity
            end
          end

        # Apply updates
        create_activities =
          create_activities.map do |activity|
            updated_object = updated_object_map[resolve_id(activity.json["object"])]
            activity.json["object"] = updated_object if updated_object
            activity
          end

        # Resolve objects
        @remote_collections_by_ap_id = {}
        create_activities.each do |activity|
          actor_json = resolve_object(activity.json["actor"])
          next unless actor_json

          object_json = resolve_object(activity.json["object"])
          next unless object_json

          activity.actor = DiscourseActivityPub::AP::Actor.factory(actor_json)
          next unless activity.actor

          next unless [AP::Actor::Person.type, AP::Actor::Group.type].include?(activity.actor.type)

          activity.object = DiscourseActivityPub::AP::Object.factory(object_json)
          next unless activity.object
          next if actor.model.activity_pub_first_post && activity.object.json[:inReplyTo]

          if activity.object.json[:attributedTo].present?
            activity.object.attributed_to =
              if activity.actor.json[:id] == activity.object.json[:attributedTo]
                activity.actor
              elsif attributed_to_json = resolve_object(activity.object.json[:attributedTo])
                DiscourseActivityPub::AP::Actor.factory(attributed_to_json)
              end
          end

          unless [AP::Object::Note.type, AP::Object::Article.type].include?(activity.object.type)
            next
          end

          if actor.model.activity_pub_full_topic
            context_or_target_id = activity.object.json[:context] || activity.object.json[:target]

            if context_or_target_id
              collection = remote_collections_by_ap_id[context_or_target_id]

              if collection
                activity.object.context = collection
              else
                collection_json = resolve_object(context_or_target_id)

                if collection_json
                  collection = DiscourseActivityPub::AP::Collection.factory(collection_json)

                  if collection.collection?
                    activity.object.context = collection
                    remote_collections_by_ap_id[collection.json[:id]] = collection
                  end
                end
              end
            end
          end

          result.activities_by_ap_id[activity.json[:id]] = activity
        end
      end

      def process_users
        result.actors_by_ap_id = store_actors(build_actors)
        create_users_from_actors
        update_activities_from_stored_actors
      end

      def process_posts
        @created_replies_count = 0
        @created_topics_count = 0

        post_object_attrs, reply_object_attrs = build_post_and_reply_objects
        post_object_attrs = update_post_object_attrs_from_stored(post_object_attrs)

        if actor.model.activity_pub_full_topic
          collection_attrs = []

          post_object_attrs.each do |object_attrs|
            collection_attrs << build_collection_attrs(object_attrs)
          end

          result.collections_by_ap_id = store_collections(collection_attrs)

          update_activites_from_stored_collections

          post_object_attrs.each do |object_attrs|
            collection = result.collections_by_ap_id[object_attrs[:context]]
            object_attrs[:collection_id] = collection.id if collection
          end
        end

        create_posts_from_objects(post_object_attrs, reply_object_attrs)

        result.activities_by_ap_id = store_activities(build_activities)
      end

      def build_activities
        result
          .activities
          .each_with_object([]) do |activity, activities|
            activities << build_activity_attrs(activity) if activity.object.stored
          end
      end

      def build_actors
        actors_by_ap_id = {}

        result.activities.each do |activity|
          actors_by_ap_id[activity.actor.json[:id]] = activity.actor

          if activity.object.attributed_to
            actors_by_ap_id[activity.object.attributed_to.json[:id]] = activity.object.attributed_to
          end
        end

        actors_by_ap_id.values.map { |actor| build_actor_attrs(actor) }
      end

      def build_post_and_reply_objects
        post_object_attrs = []
        reply_object_attrs = []

        result.activities.each do |activity|
          object = activity.object

          if object.json[:inReplyTo].present?
            reply_object_attrs << build_object_attrs(object)
          else
            post_object_attrs << build_object_attrs(object)
          end
        end

        [post_object_attrs, reply_object_attrs]
      end

      def create_users_from_actors
        result.users_by_actor_ap_id = {}

        created_users = 0
        updated_users = 0

        result.actors_by_ap_id.each do |actor_ap_id, actor|
          creating = !actor.model
          user = DiscourseActivityPub::ActorHandler.update_or_create_user(actor)

          if user
            if creating
              created_users += 1
            else
              updated_users += 1
            end
            result.users_by_actor_ap_id[actor.ap_id] = user
          end
        end

        log("created", "users", created_users) if created_users > 0
        log("updated", "users", updated_users) if updated_users > 0

        update_actors = []

        result.users_by_actor_ap_id.each do |actor_ap_id, user|
          actor = result.actors_by_ap_id[actor_ap_id]

          update_actors << {
            ap_id: actor.ap_id,
            ap_type: actor.ap_type,
            model_type: "User",
            model_id: user.id,
          }
        end

        if update_actors.any?
          DiscourseActivityPubActor.upsert_all(
            update_actors,
            unique_by: %i[ap_id],
            update_only: %i[model_type model_id],
          )
        end
      end

      def create_posts_from_objects(first_post_object_attrs, reply_object_attrs)
        result.posts_by_object_ap_id = {}
        result.topics_by_collection_ap_id = {}

        objects_by_ap_id = create_posts(first_post_object_attrs, "first_post")

        log("created", "topics", created_topics_count) if created_topics_count > 0

        if actor.model.activity_pub_full_topic
          reply_object_attrs = update_reply_object_attrs_from_stored(reply_object_attrs)
          reply_objects_by_ap_id = create_posts(reply_object_attrs, "reply")
          objects_by_ap_id = objects_by_ap_id.merge(reply_objects_by_ap_id)
        end

        result.objects_by_ap_id = objects_by_ap_id

        log("created", "replies", created_replies_count) if created_replies_count > 0

        update_post_associations_and_remove_orphaned_objects
      end

      def create_posts(object_attrs, type)
        create_post_opts_by_ap_id = {}

        object_attrs.each do |attrs|
          if attrs[:create_post_opts]
            create_post_opts_by_ap_id[attrs[:ap_id]] = attrs.delete(:create_post_opts)
          end
        end

        objects_by_ap_id = store_objects(object_attrs)

        result.activities.each do |activity|
          object_ap_id = activity.object.json[:id]

          if objects_by_ap_id[object_ap_id]
            activity.object.stored = objects_by_ap_id[object_ap_id]
            post = create_post(activity, create_post_opts_by_ap_id)
            objects_by_ap_id.delete(object_ap_id) unless post
          end
        end

        objects_by_ap_id
      end

      def create_post(activity, create_post_opts_by_ap_id)
        object = activity.object
        post = object.stored.model

        if !post
          create_post_opts = create_post_opts_by_ap_id[object.stored.ap_id] || {}
          post_actor_ap_id = object.attributed_to ? object.attributed_to.stored.ap_id : actor.ap_id

          post =
            DiscourseActivityPub::PostHandler.create(
              result.users_by_actor_ap_id[post_actor_ap_id],
              object.stored,
              **create_post_opts.merge(category_id: actor.model.id, import_mode: true),
            )

          if post.present?
            if create_post_opts[:topic_id]
              @created_replies_count += 1
            else
              @created_topics_count += 1
            end
          end
        end

        if post.present?
          result.posts_by_object_ap_id[object.stored.ap_id] = post

          if actor.model.activity_pub_full_topic
            result.topics_by_collection_ap_id[object.stored.collection.ap_id] = post.topic
          end

          true
        else
          result.activities_by_ap_id.delete(activity.json[:ap_id])
          false
        end
      end

      def update_post_object_attrs_from_stored(post_object_attrs)
        stored =
          DiscourseActivityPubObject
            .joins(
              "INNER JOIN discourse_activity_pub_collections c ON discourse_activity_pub_objects.collection_id = c.id",
            )
            .where(ap_id: post_object_attrs.map { |o| o[:ap_id] })
            .pluck("discourse_activity_pub_objects.ap_id, c.ap_id, c.id")

        object_context_by_ap_id =
          stored.each_with_object({}) do |row, result|
            result[row[0]] = { collection_ap_id: row[1], collection_id: row[2] }
          end

        post_object_attrs.each do |post_object|
          context_attrs = object_context_by_ap_id[post_object[:ap_id]]

          if context_attrs
            post_object[:context] = context_attrs[:collection_ap_id]
            post_object[:collection_id] = context_attrs[:collection_id]
          end
        end

        post_object_attrs
      end

      def update_reply_object_attrs_from_stored(reply_object_attrs)
        reply_to_ap_ids = reply_object_attrs.map { |o| o[:reply_to_id] }
        in_reply_to =
          DiscourseActivityPubObject.where(ap_id: reply_to_ap_ids).pluck(
            :ap_id,
            :context,
            :collection_id,
          )

        in_reply_to_context_by_ap_id =
          in_reply_to.each_with_object({}) do |row, result|
            result[row[0]] = { context: row[1], collection_id: row[2] }
          end

        reply_object_attrs.each_with_object([]) do |reply_object, reply_objects|
          context_attrs = in_reply_to_context_by_ap_id[reply_object[:reply_to_id]]
          reply_to_post = result.posts_by_object_ap_id[reply_object[:reply_to_id]]

          if reply_to_post && context_attrs
            reply_object[:create_post_opts] = {
              topic_id: reply_to_post.topic_id,
              reply_to_post_number: reply_to_post.post_number,
            }
            reply_object[:context] = context_attrs[:context]
            reply_object[:collection_id] = context_attrs[:collection_id]
            reply_objects << reply_object
          end
        end
      end

      def update_activities_from_stored_actors
        result.activities_by_ap_id.each do |activity_ap_id, activity|
          actor_ap_id = resolve_id(activity.json[:actor])

          if result.actors_by_ap_id[actor_ap_id] && result.users_by_actor_ap_id[actor_ap_id]
            activity.actor.stored = result.actors_by_ap_id[actor_ap_id]
          else
            result.activities_by_ap_id.delete(activity_ap_id)
          end

          if activity.object.attributed_to.present?
            attributed_to_ap_id = resolve_id(activity.object.attributed_to.json[:id])

            if result.actors_by_ap_id[attributed_to_ap_id] &&
                 result.users_by_actor_ap_id[attributed_to_ap_id]
              activity.object.attributed_to.stored = result.actors_by_ap_id[attributed_to_ap_id]
            else
              result.activities_by_ap_id.delete(activity_ap_id)
            end
          end
        end
      end

      def update_activites_from_stored_collections
        result.activities_by_ap_id.each do |activity_ap_id, activity|
          collection_ap_id =
            (
              if activity.object.context
                activity.object.context.json[:id]
              else
                activity.object.json[:context]
              end
            )

          if collection_ap_id
            collection = result.collections_by_ap_id[collection_ap_id]

            if collection
              activity.object.context = collection.ap
            else
              result.activities_by_ap_id.delete(activity_ap_id)
            end
          end
        end
      end

      def update_post_associations_and_remove_orphaned_objects
        destroy_object_ap_ids = []
        update_objects = []

        result.objects_by_ap_id.each do |object_ap_id, object|
          post = result.posts_by_object_ap_id[object_ap_id]

          if post
            update_objects << {
              ap_id: object_ap_id,
              ap_type: object.ap_type,
              model_type: "Post",
              model_id: post.id,
            }
          else
            destroy_object_ap_ids << object_ap_id
          end
        end

        if update_objects.any?
          DiscourseActivityPubObject.upsert_all(
            update_objects,
            unique_by: %i[ap_id],
            update_only: %i[model_type model_id],
          )
        end

        if destroy_object_ap_ids.any?
          DiscourseActivityPubObject.where(ap_id: destroy_object_ap_ids).destroy_all

          result.activities_by_ap_id.each do |activity_ap_id, activity|
            if destroy_object_ap_ids.include?(resolve_id(activity.json[:object]))
              result.activities_by_ap_id.delete(activity_ap_id)
            end
          end

          result.objects_by_ap_id =
            result.objects_by_ap_id.select do |object_ap_id, object|
              destroy_object_ap_ids.exclude?(object_ap_id)
            end
        end

        if actor.model.activity_pub_full_topic
          update_collections = []
          destroy_collection_ids = []

          result.collections_by_ap_id.each do |collection_ap_id, collection|
            topic = result.topics_by_collection_ap_id[collection_ap_id]

            if topic
              update_collections << {
                ap_id: collection_ap_id,
                ap_type: collection.ap_type,
                model_type: "Topic",
                model_id: topic.id,
              }
            else
              destroy_collection_ids << collection_ap_id
            end
          end

          if update_collections.any?
            DiscourseActivityPubCollection.upsert_all(
              update_collections,
              unique_by: %i[ap_id],
              update_only: %i[model_type model_id],
            )
          end

          if destroy_collection_ids.any?
            DiscourseActivityPubCollection.where(id: destroy_collection_ids).destroy_all
          end
        end
      end

      def build_activity_attrs(activity)
        {
          local: false,
          ap_id: activity.json[:id],
          ap_type: activity.type,
          actor_id: activity.actor.stored.id,
          object_id: activity.object.stored.id,
          object_type: activity.object.stored.class.name,
          visibility:
            DiscourseActivityPubActivity.visibilities[
              DiscourseActivityPub::JsonLd.publicly_addressed?(activity.json) ? :public : :private
            ],
          published_at: activity.json[:published],
        }
      end

      def build_actor_attrs(actor)
        attrs = {
          local: false,
          ap_id: actor.json[:id],
          ap_type: actor.json[:type],
          domain: domain_from_id(actor.json[:id]),
          username: actor.json[:preferredUsername],
          inbox: actor.json[:inbox],
          outbox: actor.json[:outbox],
          name: actor.json[:name],
          icon_url: resolve_icon_url(actor.json[:icon]),
          public_key: nil,
        }

        if actor.json["publicKey"].is_a?(Hash) && actor.json["publicKey"]["publicKeyPem"]
          attrs[:public_key] = actor.json["publicKey"]["publicKeyPem"]
        end

        attrs
      end

      def build_object_attrs(object)
        {
          local: false,
          ap_id: object.json[:id],
          ap_type: object.json[:type],
          content: object.json[:content],
          published_at: object.json[:published],
          domain: domain_from_id(object.json[:id]),
          name: object.json[:name],
          audience: object.json[:audience],
          context: object.json[:context],
          target: object.json[:target],
          reply_to_id: object.json[:inReplyTo],
          url: object.json[:url],
          attributed_to_id: object.attributed_to&.id,
        }
      end

      def build_collection_attrs(object_attrs)
        if object_attrs[:collection_id]
          {
            local: nil,
            ap_id: object_attrs[:context],
            ap_key: nil,
            ap_type: AP::Collection::OrderedCollection.type,
            name: object_attrs[:name],
            audience: nil,
            published_at: nil,
          }
        elsif collection = remote_collections_by_ap_id[object_attrs[:context]]
          {
            local: false,
            ap_key: nil,
            ap_id: collection.json[:id],
            ap_type: AP::Collection::OrderedCollection.type,
            name: collection.json[:name],
            audience: collection.json[:audience],
            published_at: collection.json[:published],
          }
        else
          ap_key = generate_key
          ap_id = json_ld_id(AP::Collection.type, ap_key)
          object_attrs[:context] = ap_id
          {
            local: true,
            ap_key: ap_key,
            ap_id: ap_id,
            ap_type: AP::Collection::OrderedCollection.type,
            name: object_attrs[:name],
            audience: object_attrs[:audience],
            published_at: object_attrs[:published],
          }
        end
      end

      def store_actors(actor_attrs)
        return {} unless actor_attrs.present?

        stored =
          DiscourseActivityPubActor.upsert_all(
            actor_attrs,
            unique_by: %i[ap_id],
            update_only: %i[domain username inbox outbox name icon_url public_key],
            returning: Arel.sql("*, (xmax = '0') as inserted"),
          )

        log_stored(stored, "actors")

        stored.each_with_object({}) do |attrs, result|
          actor = DiscourseActivityPubActor.new(attrs.except("inserted"))
          result[actor.ap_id] = actor
        end
      end

      def store_objects(object_attrs)
        return {} unless object_attrs.present?

        stored =
          DiscourseActivityPubObject.upsert_all(
            object_attrs,
            unique_by: %i[ap_id],
            update_only: %i[
              content
              domain
              name
              audience
              context
              target
              reply_to_id
              url
              attributed_to_id
            ],
            returning: Arel.sql("*, (xmax = '0') as inserted"),
          )

        log_stored(stored, "objects")

        stored.each_with_object({}) do |attrs, result|
          object = DiscourseActivityPubObject.new(attrs.except("inserted"))
          result[object.ap_id] = object
        end
      end

      def store_activities(activity_attrs)
        return {} unless activity_attrs.present?

        stored =
          DiscourseActivityPubActivity.upsert_all(
            activity_attrs,
            unique_by: %i[ap_id],
            update_only: %i[visibility],
            returning: Arel.sql("*, (xmax = '0') as inserted"),
          )

        log_stored(stored, "activities")

        stored.each_with_object({}) do |attrs, result|
          object = DiscourseActivityPubActivity.new(attrs.except("inserted"))
          result[object.ap_id] = object
        end
      end

      def store_collections(collection_attrs)
        return {} unless collection_attrs.present?

        stored =
          DiscourseActivityPubCollection.upsert_all(
            collection_attrs,
            unique_by: %i[ap_id],
            update_only: %i[name],
            returning: Arel.sql("*, (xmax = '0') as inserted"),
          )

        log_stored(stored, "collections")

        stored.each_with_object({}) do |attrs, result|
          collection = DiscourseActivityPubCollection.new(attrs.except("inserted"))
          result[collection.ap_id] = collection
        end
      end

      def log_process_failed(key)
        message =
          I18n.t(
            "discourse_activity_pub.bulk.process.warning.did_not_start",
            actor: actor.handle,
            target_actor: target_actor.handle,
          )
        message +=
          ": " +
            I18n.t(
              "discourse_activity_pub.bulk.process.warning.#{key}",
              actor: actor.handle,
              target_actor: target_actor.handle,
            )
        DiscourseActivityPub::Logger.warn(message)
      end

      def log_process(key)
        DiscourseActivityPub::Logger.info(
          I18n.t(
            "discourse_activity_pub.bulk.process.info.#{key}",
            actor: actor.handle,
            target_actor: target_actor.handle,
          ),
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
          I18n.t("discourse_activity_pub.bulk.process.info.#{action}_#{type}", count: count),
        )
      end
    end
  end
end
