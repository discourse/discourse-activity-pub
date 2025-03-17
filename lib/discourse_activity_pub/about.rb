# frozen_string_literal: true

module DiscourseActivityPub
  class About
    include ActiveModel::Serialization

    def actors
      @actors ||=
        DiscourseActivityPubActor.local.active.includes(:model).group(:id).left_joins(:followers)
    end

    def category_actors
      @categories ||=
        actors.where(model_type: "Category").order("COUNT(discourse_activity_pub_actors.id) DESC")
    end

    def tag_actors
      @tags ||=
        actors.where(model_type: "Tag").order("COUNT(discourse_activity_pub_actors.id) DESC")
    end
  end
end
