# frozen_string_literal: true

module Jobs
  class DiscourseActivityPubDestroyActor < ::Jobs::Base
    def execute(args)
      actor = DiscourseActivityPubActor.find_by(id: args[:actor_id])
      return unless actor

      handler = DiscourseActivityPub::ActorHandler.new(actor: actor)
      handler.destroy_actor
    end
  end
end
