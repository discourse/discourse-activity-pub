# frozen_string_literal: true

module DiscourseActivityPub
  class CategoryController < ApplicationController
    PAGE_SIZE = 50
    ORDER = %w(actor user followed_at)

    before_action :ensure_site_enabled
    before_action :find_category

    def index
    end

    def followers
      guardian.ensure_can_see!(@category)

      followers = @category
        .activity_pub_followers
        .joins(:follow_follows)
        .where(follow_follows: { followed_id: @category.activity_pub_actor.id })
        .joins(:user)
        .order("#{order_table}.#{order} #{params[:asc] ? "ASC" : "DESC"}")

      limit = fetch_limit_from_params(default: PAGE_SIZE, max: PAGE_SIZE)
      page = fetch_int_from_params(:page, default: 0)
      total = followers.count
      followers = followers.limit(limit).offset(limit * page).to_a

      render_json_dump(
        followers: serialize_data(followers, FollowerSerializer, root: false),
        meta: {
          total: total,
          load_more_url: load_more_url(page),
        }
      )
    end

    protected

    def permitted_order
      @permitted_order ||= ORDER.find { |attr| attr == params[:order] }
    end

    def order_table
      case permitted_order
      when 'actor' then 'discourse_activity_pub_actors'
      when 'user' then 'users'
      when 'followed_at' then 'discourse_activity_pub_follows'
      else 'discourse_activity_pub_follows'
      end
    end

    def order
      case permitted_order
      when 'actor' then 'username'
      when 'user' then 'username'
      when 'followed_at' then 'created_at'
      else 'created_at'
      end
    end

    def load_more_url(page)
      load_more_params = params.slice(:order, :asc).permit!
      load_more_params[:page] = page + 1
      load_more_uri = ::URI.parse("/ap/category/#{params[:category_id]}/followers.json")
      load_more_uri.query = ::URI.encode_www_form(load_more_params.to_h)
      load_more_uri.to_s
    end

    def find_category
      @category = Category.find_by_id(params.require(:category_id))
      render_category_error("category_not_found", 400) unless @category.present?
    end

    def ensure_site_enabled
      render_category_error("not_enabled", 403) unless DiscourseActivityPub.enabled
    end

    def render_category_error(key, status)
      render_json_error I18n.t("discourse_activity_pub.category.error.#{key}"), status: status
    end
  end
end