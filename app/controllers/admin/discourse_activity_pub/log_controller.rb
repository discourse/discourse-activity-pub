# frozen_string_literal: true

module Admin::DiscourseActivityPub
  class LogController < ::Admin::AdminController
    requires_plugin DiscourseActivityPub::PLUGIN_NAME

    include DiscourseActivityPub::EnabledVerification

    before_action :ensure_site_enabled

    ORDER_BY = { "level" => "level" }

    def index
      logs = DiscourseActivityPubLog.all

      offset = params[:offset].to_i || 0
      load_more_query_params = { offset: offset + 1 }
      load_more_query_params[:order] = params[:order] if !params[:order].nil?
      load_more_query_params[:asc] = params[:asc] if !params[:asc].nil?

      total = logs.count
      order = ORDER_BY.fetch(params[:order], "created_at")
      direction = params[:asc] == "true" ? "ASC" : "DESC"
      logs = logs.order("#{order} #{direction}").limit(page_limit).offset(offset * page_limit)

      load_more_url = URI("/admin/plugins/ap/log.json")
      load_more_url.query = ::URI.encode_www_form(load_more_query_params)

      render_serialized(
        logs,
        DiscourseActivityPub::Admin::LogSerializer,
        root: "logs",
        meta: {
          total: total,
          load_more_url: load_more_url.to_s,
        },
      )
    end

    protected

    def page_limit
      30
    end
  end
end
