# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::Admin::ActorController do
  fab!(:admin)

  it { expect(described_class).to be < DiscourseActivityPub::Admin::AdminController }

  before { sign_in(admin) }

  def actor_error(key)
    I18n.t("discourse_activity_pub.actor.error.#{key}")
  end

  def actor_warning(key)
    I18n.t("discourse_activity_pub.actor.warning.#{key}")
  end

  describe "#index" do
    context "without a model type" do
      it "returns a 400 error" do
        get "/admin/plugins/ap/actor.json"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(
          "param is missing or the value is empty: model_type",
        )
      end
    end

    context "with an invalid model type" do
      it "returns a 400 error" do
        get "/admin/plugins/ap/actor.json?model_type=user"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(actor_error("invalid_model"))
      end
    end

    context "with a valid model type" do
      it "returns administrable actors of that model type" do
        actor1 = Fabricate(:discourse_activity_pub_actor_group)
        actor2 = Fabricate(:discourse_activity_pub_actor_group)
        actor3 = Fabricate(:discourse_activity_pub_actor_person)
        actor4 = Fabricate(:discourse_activity_pub_actor_group, local: false)
        get "/admin/plugins/ap/actor.json?model_type=category"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].size).to eq(2)
      end
    end
  end

  describe "#show" do
    context "with an administratable actor" do
      it "returns the actor" do
        actor = Fabricate(:discourse_activity_pub_actor_group)
        get "/admin/plugins/ap/actor/#{actor.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["id"]).to eq(actor.id)
      end
    end

    context "with a non-administrable actor" do
      it "returns an actor not found error" do
        actor = Fabricate(:discourse_activity_pub_actor_person)
        get "/admin/plugins/ap/actor/#{actor.id}.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(actor_error("actor_not_found"))
      end
    end
  end

  describe "#create" do
    context "without a model" do
      it "returns a 400" do
        post "/admin/plugins/ap/actor.json", params: { actor: { model_id: 1 } }
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(actor_error("invalid_model"))
      end
    end

    context "with an invalid model" do
      it "returns a 400" do
        post "/admin/plugins/ap/actor.json",
             params: {
               actor: {
                 model_type: "Topic",
                 model_id: 30,
               },
             }
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(actor_error("invalid_model"))
      end
    end

    context "when the model cant be found" do
      it "returns a 404" do
        post "/admin/plugins/ap/actor.json",
             params: {
               actor: {
                 model_type: "Category",
                 model_id: 30,
               },
             }
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(actor_error("model_not_found"))
      end
    end

    context "with a valid model" do
      let!(:category) { Fabricate(:category) }

      context "without a username" do
        it "returns a 400" do
          post "/admin/plugins/ap/actor.json",
               params: {
                 actor: {
                   model_type: "Category",
                   model_id: category.id,
                 },
               }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(actor_error("username_required"))
        end
      end

      context "with private visibility and full topic publication" do
        it "returns a 400" do
          post "/admin/plugins/ap/actor.json",
               params: {
                 actor: {
                   model_type: "Category",
                   model_id: category.id,
                   username: "new_actor",
                   default_visibility: "private",
                   publication_type: "full_topic",
                 },
               }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(
            actor_error("full_topic_must_be_public"),
          )
        end
      end

      context "with valid params" do
        it "returns a new actor" do
          post "/admin/plugins/ap/actor.json",
               params: {
                 actor: {
                   model_type: "Category",
                   model_id: category.id,
                   username: "new_actor",
                   default_visibility: "public",
                   publication_type: "full_topic",
                 },
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["username"]).to eq("new_actor")
          expect(response.parsed_body["actor"]["model"]["id"]).to eq(category.id)
          expect(response.parsed_body["actor"]["default_visibility"]).to eq("public")
          expect(response.parsed_body["actor"]["publication_type"]).to eq("full_topic")
        end
      end
    end
  end

  describe "#update" do
    let!(:category) { Fabricate(:category) }

    context "when the actor cant be found" do
      it "returns a 404" do
        put "/admin/plugins/ap/actor/30.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(actor_error("actor_not_found"))
      end
    end

    context "with a valid actor" do
      let!(:actor) do
        Fabricate(:discourse_activity_pub_actor_group, model: category, enabled: true)
      end

      context "without a username" do
        it "returns a 400" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
                  model_type: "Category",
                  model_id: category.id,
                },
              }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(actor_error("username_required"))
        end
      end

      context "with private visibility and full topic publication" do
        it "returns a 400" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
                  model_type: "Category",
                  model_id: category.id,
                  username: actor.username,
                  default_visibility: "private",
                  publication_type: "full_topic",
                },
              }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(
            actor_error("full_topic_must_be_public"),
          )
        end
      end

      context "with a new username" do
        it "returns the right error" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
                  model_type: "Category",
                  model_id: category.id,
                  username: "new_actor",
                  default_visibility: "public",
                  publication_type: "full_topic",
                },
              }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(actor_warning("no_change_when_set"))
        end
      end

      context "with valid params" do
        it "returns a new actor" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
                  model_type: "Category",
                  model_id: category.id,
                  username: actor.username,
                  default_visibility: "public",
                  publication_type: "full_topic",
                },
              }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["username"]).to eq(actor.username)
          expect(response.parsed_body["actor"]["model"]["id"]).to eq(category.id)
          expect(response.parsed_body["actor"]["default_visibility"]).to eq("public")
          expect(response.parsed_body["actor"]["publication_type"]).to eq("full_topic")
        end
      end
    end
  end
end
