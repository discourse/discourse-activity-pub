# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class AuthorizationController < AuthController
      def destroy
        params.require(:actor_id)

        if current_user.activity_pub_remove_actor_id(params[:actor_id])
          render json: success_json
        else
          render json: failed_json, status: 422
        end
      end
    end
  end
end
