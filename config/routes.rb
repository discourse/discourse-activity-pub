# frozen_string_literal: true

DiscourseActivityPub::Engine.routes.draw do
  scope "/post", defaults: { format: :json } do
    post "schedule/:post_id" => "post#schedule"
    delete "schedule/:post_id" => "post#unschedule"
    post "deliver/:post_id" => "post#deliver"
    post "publish/:post_id" => "post#publish"
  end

  scope "/topic", defaults: { format: :json } do
    post "publish/:topic_id" => "topic#publish"
  end

  get "/auth" => "authorization#index", :defaults => { format: :json }
  scope "/auth", defaults: { format: :json } do
    post "verify" => "authorization#verify"
    get "authorize/:auth_type" => "authorization#authorize"
    get "redirect/:auth_type" => "authorization#redirect"
    delete "destroy/:auth_id" => "authorization#destroy"
  end

  get "/about" => "about#index"

  scope "/local" do
    scope "/actor" do
      get "/find-by-user" => "actor#find_by_user", :defaults => { format: :json }
      get ":actor_id" => "actor#show"
      get ":actor_id/followers" => "actor#followers"
      get ":actor_id/follows" => "actor#follows"
      post ":actor_id/follow" => "actor#follow", :defaults => { format: :json }
      delete ":actor_id/follow" => "actor#unfollow", :defaults => { format: :json }
      post ":actor_id/reject" => "actor#reject", :defaults => { format: :json }
      get ":actor_id/find-by-handle" => "actor#find_by_handle", :defaults => { format: :json }
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

Discourse::Application.routes.append do
  mount ::DiscourseActivityPub::Engine, at: "ap"

  get ".well-known/webfinger" => "discourse_activity_pub/webfinger#index"
  post "/webfinger/handle/validate" => "discourse_activity_pub/webfinger/handle#validate",
       :defaults => {
         format: :json,
       }
  get "u/:username/preferences/activity-pub" => "users#preferences",
      :constraints => {
        username: RouteFormat.username,
      }

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/ap" => "admin/plugins#index"
    get "/admin/plugins/ap/actor" => "admin/discourse_activity_pub/actor#index"
    post "/admin/plugins/ap/actor" => "admin/discourse_activity_pub/actor#create",
         :constraints => {
           format: :json,
         }
    get "/admin/plugins/ap/actor/:actor_id" => "admin/discourse_activity_pub/actor#show"
    put "/admin/plugins/ap/actor/:actor_id" => "admin/discourse_activity_pub/actor#update",
        :constraints => {
          format: :json,
        }
    delete "/admin/plugins/ap/actor/:actor_id" => "admin/discourse_activity_pub/actor#delete"
    post "/admin/plugins/ap/actor/:actor_id/enable" => "admin/discourse_activity_pub/actor#enable"
    post "/admin/plugins/ap/actor/:actor_id/disable" => "admin/discourse_activity_pub/actor#disable"
    get "/admin/plugins/ap/log" => "admin/discourse_activity_pub/log#index"
  end
end
