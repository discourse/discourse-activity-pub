# frozen_string_literal: true

module DiscourseActivityPub
  class ActorSerializer < BasicActorSerializer
    attributes :name,
               :ap_type,
               :model_id,
               :model_type,
               :model_name,
               :can_admin,
               :default_visibility,
               :publication_type,
               :post_object_type,
               :enabled,
               :ready

    def model_type
      object.model_type&.downcase
    end

    def model_name
      object.model.name
    end

    def include_model_name?
      object.model_type === "Tag"
    end

    def can_admin
      scope&.can_admin?(object)
    end

    def default_visibility
      object.default_visibility
    end

    def publication_type
      object.publication_type
    end

    def post_object_type
      object.post_object_type
    end

    def enabled
      object.enabled
    end

    def include_enabled?
      object.model.present?
    end

    def ready
      object.model.activity_pub_ready?
    end

    def include_ready?
      object.model.present?
    end
  end
end
