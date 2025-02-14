# frozen_string_literal: true

module DiscourseActivityPub
  class DetailedActorSerializer < ActorSerializer
    attributes :local, :url, :icon_url, :followed_at, :model

    def model
      case object.model_type
      when "User"
        BasicUserSerializer.new(object.model, root: false).as_json
      when "Category"
        SiteCategorySerializer.new(object.model, root: false).as_json
      when "Tag"
        TagSerializer.new(object.model, root: false).as_json
      end
    end
  end
end
