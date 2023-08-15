# frozen_string_literal: true

DiscourseActivityPub::Engine.routes.draw do
  scope module: 'a_p' do
    get "actor/:key" => "actors#show"
    post "actor/:key/inbox" => "inboxes#create"
    get "actor/:key/outbox" => "outboxes#index"
    get "actor/:key/followers" => "followers#index"
    get "activity/:key" => "activities#show"
    get "object/:key" => "objects#show"
  end

  get "auth" => "auth#index", defaults: { format: :json }
  scope module: "auth", path: "auth", defaults: { format: :json } do
    delete "authorization" => "authorization#destroy"

    post "oauth/verify" => "o_auth#verify"
    get "oauth/authorize" => "o_auth#authorize"
    get "oauth/redirect" => "o_auth#redirect"
  end
end