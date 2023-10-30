# frozen_string_literal: true

module DiscourseActivityPub
  class CategoryController < ApplicationController
    PAGE_SIZE = 50
    ORDER = %w(domain username followed_at)

    before_action :ensure_site_enabled
    before_action :find_category

    def index
    end

    def followers
      guardian.ensure_can_see!(@category)

      order_followed_at = params[:order] == 'followed_at'
      permitted_order = ORDER.find { |attr| attr == params[:order] }
      order = (order_followed_at || !permitted_order) ? 'created_at' : permitted_order
      order_dir = params[:asc] ? "ASC" : "DESC"
      order_table = order == 'created_at' ? 'discourse_activity_pub_follows' : 'discourse_activity_pub_actors'

      followers = @category
        .activity_pub_followers
        .joins(:follow_follows)
        .where(follow_follows: { followed_id: @category.activity_pub_actor.id })
        .order("#{order_table}.#{order} #{order_dir}")

      limit = fetch_limit_from_params(default: PAGE_SIZE, max: PAGE_SIZE)
      page = fetch_int_from_params(:page, default: 0)
      total = followers.count
      followers = followers.limit(limit).offset(limit * page).to_a

      load_more_params = params.slice(:order, :asc).permit!
      load_more_params[:page] = page + 1
      load_more_uri = ::URI.parse("/ap/category/#{params[:category_id]}/followers.json")
      load_more_uri.query = ::URI.encode_www_form(load_more_params.to_h)

      serialized = serialize_data(followers, FollowerSerializer, root: false)
      render_json_dump(
        followers: serialized,
        meta: {
          total: total,
          load_more: load_more_uri.to_s,
        }
      )
    end

    protected

    def followers_response

    end

    def find_category
      @category = Category.find_by_id(params.require(:category_id))
      return render_category_error("category_not_found", 400) unless @category.present?
    end

    def ensure_site_enabled
      render_category_error("not_enabled", 403) unless DiscourseActivityPub.enabled
    end

    def render_category_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.category.error.#{key}"), status: status
    end
  end
end