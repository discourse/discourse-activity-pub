# frozen_string_literal: true

module DiscourseActivityPub
  class Admin::ActorSerializer < ActorSerializer
    attributes :model_type,
               :model_id,
               :enabled,
               :default_visibility,
               :publication_type,
               :post_object_type

    def include_model?
      true
    end

    def model_type
      object.model_type.downcase
    end

    def enabled
      object.model.activity_pub_enabled
    end

    def default_visibility
      object.model.activity_pub_default_visibility
    end

    def publication_type
      object.model.activity_pub_publication_type
    end

    def post_object_type
      object.model.activity_pub_post_object_type
    end
  end
end
