# frozen_string_literal: true

module DiscourseActivityPub
  class ActorSerializer < BasicActorSerializer
    attributes :local, :domain, :url, :icon_url, :followed_at, :model

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

    def enabled
      object.model.activity_pub_enabled
    end

    def include_enabled?
      object.model.present?
    end

    def include_model?
      @options[:include_model]
    end
  end
end
