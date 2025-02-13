# frozen_string_literal: true

module DiscourseActivityPub
  class Admin::ActorSerializer < ActorSerializer
    def include_model?
      true
    end
  end
end
