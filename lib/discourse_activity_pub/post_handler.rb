# frozen_string_literal: true
module DiscourseActivityPub
  class PostHandler
    attr_reader :user, :object

    def initialize(user, object)
      @user = user
      @object = object
    end

    def create(category_id: nil)
      if !user || !object || object.model_id || (!object.in_reply_to_post && !category_id)
        return nil
      end

      if category_id
        category = Category.find_by(id: category_id)
        return nil unless can_create_topic?(category)
      end

      new_topic = !object.in_reply_to_post && category
      params = { raw: object.content, skip_events: true, skip_validations: true, custom_fields: {} }

      if new_topic
        params[:title] = object.name ||
          DiscourseActivityPub::ContentParser.get_title(object.content)
        params[:category] = category.id
      else
        reply_to = object.in_reply_to_post
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

      ActiveRecord::Base.transaction do
        begin
          post = PostCreator.create!(user, params)
          create_collection(post) if new_topic
        rescue PG::UniqueViolation,
               ActiveRecord::RecordNotUnique,
               ActiveRecord::RecordInvalid,
               DiscourseActivityPub::AP::Handlers => e
          DiscourseActivityPub::Logger.warn(
            I18n.t(
              "discourse_activity_pub.post.error.failed_to_create",
              user: user.username,
              object: object.id,
              message: e.message,
            ),
          )
          raise ActiveRecord::Rollback
        end

        if post
          object.update(
            model_type: "Post",
            model_id: post.id,
            collection_id: post.topic.activity_pub_object.id,
          )
        end
      end

      post
    end

    def self.create(user, object, category_id: nil)
      new(user, object).create(category_id: category_id)
    end

    protected

    def can_create_topic?(category)
      category&.activity_pub_ready?
    end

    def create_collection(post)
      # See https://codeberg.org/fediverse/fep/src/branch/main/fep/400e/fep-400e.md
      # See https://socialhub.activitypub.rocks/t/standardizing-on-activitypub-groups/1984
      raw_collection = object.context || object.target

      if raw_collection
        collection = DiscourseActivityPub::AP::Collection.resolve_and_store(raw_collection)

        if collection
          collection.stored.update(model_type: "Topic", model_id: post.topic.id)
        else
          raise DiscourseActivityPub::AP::Handlers::Error::Store,
                I18n.t(
                  "discourse_activity_pub.process.error.failed_to_save_collection",
                  collection_id: DiscourseActivityPub::JsonLd.resolve_id(raw_collection),
                )
        end
      else
        post.topic.create_activity_pub_collection!
      end
    end
  end
end
