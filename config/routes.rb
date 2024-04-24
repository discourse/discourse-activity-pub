# frozen_string_literal: true

DiscourseActivityPub::Engine.routes.draw do
  scope "/post", defaults: { format: :json } do
    post "schedule/:post_id" => "post#schedule"
    delete "schedule/:post_id" => "post#unschedule"
  end

  get "auth" => "auth#index", :defaults => { format: :json }
  scope module: "auth", path: "auth", defaults: { format: :json } do
    post "verify" => "authorization#verify"
    get "verify-redirect" => "authorization#verify_redirect"
    get "authorize/:platform" => "authorization#authorize"
    get "redirect/:platform" => "authorization#redirect"
    delete "destroy" => "authorization#destroy"
  end

  scope "/local" do
    scope "/actor" do
      get ":actor_id" => "actor#show"
      get ":actor_id/followers" => "actor#followers"
      get ":actor_id/follows" => "actor#follows"
      post ":actor_id/follow" => "actor#follow", :defaults => { format: :json }
      delete ":actor_id/follow" => "actor#unfollow", :defaults => { format: :json }
      get ":actor_id/find-by-handle" => "actor#find_by_handle", :defaults => { format: :json }
      get "find-by-user" => "actor#find_by_user"
    end
  end

  scope module: "a_p" do
    get "actor/:key" => "actors#show"
    post "actor/:key/inbox" => "inboxes#create"
    get "actor/:key/outbox" => "outboxes#index"
    get "actor/:key/followers" => "followers#index"
    get "activity/:key" => "activities#show"
    get "object/:key" => "objects#show"
    get "collection/:key" => "collections#show"
    post "users/inbox" => "shared_inboxes#create"
  end
end
