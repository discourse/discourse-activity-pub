# frozen_string_literal: true

module DiscourseActivityPub
  class ActorSerializer < BasicActorSerializer
    attributes :name,
               :local,
               :domain,
               :url,
               :icon_url,
               :user,
               :followed_at

    def user
      BasicUserSerializer.new(object.model, root: false).as_json
    end

    def include_user?
      object.model_type === 'User' && object.model_id.present?
    end
  end
end
