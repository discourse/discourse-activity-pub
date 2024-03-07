# frozen_string_literal: true

module DiscourseActivityPub
  class Webfinger::HandleController < WebfingerController
    def validate
      params.require(:handle)

      handle = Webfinger::Handle.new(handle: params[:handle])

      render json: { valid: handle.valid? }
    end
  end
end
