# frozen_string_literal: true

module DiscourseActivityPub
  class AP::ActivitySerializer < DiscourseActivityPub::AP::ObjectSerializer
    attributes :actor

    def attributes(*args)
      hash = super
      hash[:object] = _object
      hash
    end

    def actor
      object.actor.json
    end

    def _object
      object.object&.json
    end
  end
end
