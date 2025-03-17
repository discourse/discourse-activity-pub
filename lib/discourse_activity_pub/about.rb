# frozen_string_literal: true

module DiscourseActivityPub
  class About
    include ActiveModel::Serialization

    def actors
      @actors ||= DiscourseActivityPubActor.local.active.includes(:model).includes(:followers)
    end

    def category_actors
      @categories ||= actors.where(model_type: "Category")
    end

    def tag_actors
      @tags ||= actors.where(model_type: "Tag")
    end
  end
end
