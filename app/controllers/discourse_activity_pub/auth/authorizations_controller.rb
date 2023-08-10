# frozen_string_literal: true

module DiscourseActivityPub
  module Auth
    class AuthorizationsController < DiscourseActivityPub::AuthController
      def index
        render_serialized(
          current_user.activity_pub_authorizations,
          DiscourseActivityPub::Auth::AuthorizationSerializer
        )
      end
    end
  end
end