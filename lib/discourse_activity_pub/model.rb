# frozen_string_literal: true

module DiscourseActivityPub
  class Model
    def self.ap_type(model)
      case model.class.name
      when 'Category' then AP::Actor::Group.type
      when 'Post' then AP::Object::Note.type
      end
    end

    def self.ready?(model)
      model.respond_to?(:activity_pub_ready?) && model.activity_pub_ready?
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

    def self.find_by_ap_id(ap_id)
      uri = Request.parse(ap_id)
      return nil unless uri && uri.domain === Discourse.current_hostname

      path_parts = uri.path.split('/').compact_blank
      return nil unless path_parts.shift === 'ap'

      stored = case path_parts.first
        when 'activity' then DiscourseActivityPubActivity.find_by(ap_key: path_parts.last)
        when 'actor' then DiscourseActivityPubActor.find_by(ap_key: path_parts.last)
        when 'object' then DiscourseActivityPubObject.find_by(ap_key: path_parts.last)
        else
          nil
        end

      stored&._model
    end
  end
end