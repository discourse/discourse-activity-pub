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
      return nil unless actor&.ready? && target_actor&.ready?

      response = DiscourseActivityPub::Request.get_json_ld(
        uri: target_actor.outbox
      )
      return nil unless response

      collection = DiscourseActivityPub::AP::Object.factory(response)
      return unless collection&.type == DiscourseActivityPub::AP::Collection::OrderedCollection.type

      log_import_start
      collection.delivered_to << actor.ap_id
      collection.process
    end

    def self.perform(actor_id: nil, target_actor_id: nil)
      new(actor_id: actor_id, target_actor_id: target_actor_id).perform
    end

    protected

    def log_import_start
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
