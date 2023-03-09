# frozen_string_literal: true

module DiscourseActivityPub
  class Model
    def self.enabled?(model)
      return false unless model.respond_to?(:activity_pub_enabled)
      model.activity_pub_enabled && model.activity_pub_ready?
    end

    def self.find_by_url(url)
      return nil unless Request.valid_url?(url)
      return nil unless UrlHelper.is_local(url)

      route = UrlHelper.rails_route_from_url(url)
      return nil if route.blank?

      case route[:action]
      when "category_default"
        Category.find_by_slug_path_with_id(route[:category_slug_path_with_id].gsub(/inbox|outbox/, ""))
      end
    end
  end
end