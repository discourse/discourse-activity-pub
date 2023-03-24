# frozen_string_literal: true

Discourse::Application.routes.append do
  get ".well-known/webfinger" => "discourse_activity_pub/webfinger#index"

  scope module: 'discourse_activity_pub/a_p', path: "/c/*category_slug_path_with_id" do
    post "inbox" => "inboxes#create"
  end
end