# frozen_string_literal: true

DiscourseActivityPub::Engine.routes.draw do
  scope '/post', defaults: { format: :json } do
    post "schedule/:post_id" => "post#schedule"
    delete "schedule/:post_id" => "post#unschedule"
  end

  scope module: 'a_p' do
    get "actor/:key" => "actors#show"
    post "actor/:key/inbox" => "inboxes#create"
    get "actor/:key/outbox" => "outboxes#index"
    get "actor/:key/followers" => "followers#index"
    get "activity/:key" => "activities#show"
    get "object/:key" => "objects#show"
  end
end

Discourse::Application.routes.append do
  get ".well-known/webfinger" => "discourse_activity_pub/webfinger#index"
  mount DiscourseActivityPub::Engine, at: "ap"
end