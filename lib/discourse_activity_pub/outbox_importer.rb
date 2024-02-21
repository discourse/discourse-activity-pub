# frozen_string_literal: true

module DiscourseActivityPub
  class OutboxImporter
    attr_reader :actor
    attr_reader :target_actor

    def initialize(actor_id: nil, target_actor_id: nil)
      @actor = DiscourseActivityPubActor.find_by(id: actor_id)
      @target_actor = DiscourseActivityPubActor.find_by(id: target_actor_id)
    end

    def perform
      return log_import_failed("actors_not_ready") if !actor&.ready? || !target_actor&.ready?
      return log_import_failed("not_following_target") if !actor.following?(target_actor)

      response = DiscourseActivityPub::Request.get_json_ld(uri: target_actor.outbox)
      return log_import_failed("outbox_response_invalid") unless response

      collection = DiscourseActivityPub::AP::Object.factory(response)
      unless collection&.type == DiscourseActivityPub::AP::Collection::OrderedCollection.type
        return log_import_failed("outbox_response_invalid")
      end

      collection.delivered_to << actor.ap_id
      log_import_started(collection.total_items)
      result = collection.process
      log_import_finished(result)
      result
    end

    def self.perform(actor_id: nil, target_actor_id: nil)
      new(actor_id: actor_id, target_actor_id: target_actor_id).perform
    end

    protected

    def log_import_failed(key)
      message =
        I18n.t(
          "discourse_activity_pub.import.warning.import_did_not_start",
          actor: actor.handle,
          target_actor: target_actor.handle,
        )
      message +=
        ": " +
          I18n.t(
            "discourse_activity_pub.import.warning.#{key}",
            actor: actor.handle,
            target_actor: target_actor.handle,
          )
      DiscourseActivityPub::Logger.warn(message)
    end

    def log_import_started(activity_count)
      DiscourseActivityPub::Logger.info(
        I18n.t(
          "discourse_activity_pub.import.info.import_started",
          actor: actor.handle,
          target_actor: target_actor.handle,
          activity_count: activity_count,
        ),
      )
    end

    def log_import_finished(result)
      DiscourseActivityPub::Logger.info(
        I18n.t(
          "discourse_activity_pub.import.info.import_finished",
          actor: actor.handle,
          target_actor: target_actor.handle,
          success_count: result[:success].size,
        ),
      )
    end
  end
end
