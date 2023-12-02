# frozen_string_literal: true

DiscourseActivityPub::Engine.routes.draw do
  scope '/post', defaults: { format: :json } do
    post "schedule/:post_id" => "post#schedule"
    delete "schedule/:post_id" => "post#unschedule"
  end

  scope '/category' do
    get ":category_id" => "category#index"
    get ":category_id/followers" => "category#followers"
    get ":category_id/follows" => "category#follows"
  end

  post "users/inbox" => "a_p/shared_inboxes#create"

  scope '/actor', defaults: { format: :json } do
    post ":actor_id/follow" => "actor#follow"
    delete ":actor_id/follow" => "actor#unfollow"
    get ":actor_id/find-by-handle" => "actor#find_by_handle"
  end

  scope module: 'a_p' do
    get "actor/:key" => "actors#show"
    post "actor/:key/inbox" => "inboxes#create"
    get "actor/:key/outbox" => "outboxes#index"
    get "actor/:key/followers" => "followers#index"
    get "activity/:key" => "activities#show"
    get "object/:key" => "objects#show"
    get "collection/:key" => "collections#show"
  end

  get "auth" => "auth#index", defaults: { format: :json }
  scope module: "auth", path: "auth", defaults: { format: :json } do
    delete "authorization" => "authorization#destroy"

    post "oauth/verify" => "o_auth#verify"
    get "oauth/authorize" => "o_auth#authorize"
    get "oauth/redirect" => "o_auth#redirect"
  end
end