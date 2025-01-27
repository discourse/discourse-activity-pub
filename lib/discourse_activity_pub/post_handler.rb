# frozen_string_literal: true
module DiscourseActivityPub
  class PostHandler
    attr_reader :user, :object

    def initialize(user, object)
      @user = user
      @object = object
    end

    def create(
      category_id: nil,
      tag_id: nil,
      topic_id: nil,
      reply_to_post_number: nil,
      import_mode: false
    )
      if !user || !object || object.model_id ||
           (!object.in_reply_to_post && !category_id && !tag_id && !topic_id)
        return nil
      end

      if category_id
        category = Category.find_by(id: category_id)
        return nil unless can_create_topic?(category)
      end
      tag = Tag.find_by(id: tag_id) if tag_id

      new_topic = !object.reply_to_id && !topic_id && (category || tag)
      reply_to = object.in_reply_to_post
      return nil if !import_mode && !new_topic && !reply_to && !topic_id

      params = {
        raw: object.content,
        skip_events: true,
        skip_validations: true,
        skip_jobs: true,
        custom_fields: {
        },
        import_mode: import_mode,
        topic_id: topic_id,
        reply_to_post_number: reply_to_post_number,
      }

      if new_topic
        params[:title] = object.name ||
          DiscourseActivityPub::ContentParser.get_title(object.content)
        params[:category] = category.id if category
        params[:topic_opts] = { tags: [tag.name] } if tag
      end

      if reply_to
        params[:topic_id] = reply_to.topic.id
        params[:reply_to_post_number] = reply_to.post_number
      end

      if object.published_at
        params[:custom_fields][:activity_pub_published_at] = object
          .published_at
          &.to_datetime
          &.utc
          &.iso8601
      end

      post = nil

      ActiveRecord::Base.transaction(requires_new: true) do
        post_creator = PostCreator.new(user, params)
        post = post_creator.create

        if !post || post_creator.errors.full_messages.present?
          DiscourseActivityPub::Logger.error(
            I18n.t(
              "discourse_activity_pub.post.error.failed_to_create",
              object_id: object.ap_id,
              message: post_creator.full_messages.join(", "),
            ),
          )
          raise ActiveRecord::Rollback
        end

        collection = create_collection(post) if new_topic && !import_mode
        if !collection
          DiscourseActivityPub::Logger.error(
            I18n.t(
              "discourse_activity_pub.post.error.failed_to_create",
              object_id: object.ap_id,
              message: "Failed to create collection"
            ),
          )
          raise ActiveRecord::Rollback
        end

        post_creator.enqueue_jobs

        if !import_mode
          object.update(
            model_type: "Post",
            model_id: post.id,
            collection_id: post.topic.activity_pub_object&.id,
          )
        end
      end

      post
    end

    def self.create(
      user,
      object,
      category_id: nil,
      tag_id: nil,
      topic_id: nil,
      reply_to_post_number: nil,
      import_mode: false
    )
      new(user, object).create(
        category_id: category_id,
        tag_id: tag_id,
        import_mode: import_mode,
        topic_id: topic_id,
        reply_to_post_number: reply_to_post_number,
      )
    end

    def self.ensure_activity_has_post(activity)
      post = activity.object.stored.model

      unless post
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.cant_find_post")
      end

      if post.trashed?
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.post_is_deleted")
      end

      unless post.activity_pub_full_topic
        raise DiscourseActivityPub::AP::Handlers::Warning::Validate,
              I18n.t("discourse_activity_pub.process.warning.full_topic_not_enabled")
      end
    end

    protected

    def can_create_topic?(category)
      category&.activity_pub_ready?
    end

    def create_collection(post)
      # See https://codeberg.org/fediverse/fep/src/branch/main/fep/400e/fep-400e.md
      # See https://socialhub.activitypub.rocks/t/standardizing-on-activitypub-groups/1984
      raw_collection = object.context || object.target
      collection = nil

      if raw_collection
        collection = DiscourseActivityPub::AP::Collection.resolve_and_store(raw_collection)

        if collection
          collection.stored.update(model_type: "Topic", model_id: post.topic.id)
          return collection
        else
          DiscourseActivityPub::Logger.error(
            I18n.t(
              "discourse_activity_pub.process.error.failed_to_save_collection",
              collection_id: DiscourseActivityPub::JsonLd.resolve_id(raw_collection),
            )
          )
        end
      end

      collection || post.topic.create_activity_pub_collection!
    end
  end
end
