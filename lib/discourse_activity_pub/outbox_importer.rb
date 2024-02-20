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
      return log_import_failed("failed_to_retrieve_outbox") unless response

      collection = DiscourseActivityPub::AP::Object.factory(response)
      unless collection&.type == DiscourseActivityPub::AP::Collection::OrderedCollection.type
        return log_import_failed("outbox_response_invalid")
      end

      log_import_started
      collection.delivered_to << actor.ap_id
      collection.process
    end

    def self.perform(actor_id: nil, target_actor_id: nil)
      new(actor_id: actor_id, target_actor_id: target_actor_id).perform
    end

    protected

    def log_import_failed(key)
      message = I18n.t(
        "discourse_activity_pub.import.warning.import_did_not_start",
        actor_id: actor.ap_id,
        target_actor_id: target_actor.ap_id
      )
      message += ": " + I18n.t(
        "discourse_activity_pub.import.warning.#{key}",
        actor_id: actor.ap_id,
        target_actor_id: target_actor.ap_id
      )
      DiscourseActivityPub::Logger.warn(message)
    end

    def log_import_started
      DiscourseActivityPub::Logger.info(
        I18n.t(
          "discourse_activity_pub.import.info.import_started",
          actor_id: actor.ap_id,
          target_actor_id: target_actor.ap_id
        ),
      )
    end
  end
end
