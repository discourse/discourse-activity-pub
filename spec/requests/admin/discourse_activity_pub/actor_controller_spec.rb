# frozen_string_literal: true

RSpec.describe Admin::DiscourseActivityPub::ActorController do
  fab!(:admin)

  it { expect(described_class).to be < Admin::AdminController }

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
          "param is missing or the value is empty or invalid: model_type",
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
      let!(:actor1) { Fabricate(:discourse_activity_pub_actor_group) }
      let!(:actor2) { Fabricate(:discourse_activity_pub_actor_group) }
      let!(:actor3) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:actor4) { Fabricate(:discourse_activity_pub_actor_group, local: false) }

      it "returns administrable actors of that model type" do
        get "/admin/plugins/ap/actor.json?model_type=category"
        expect(response.status).to eq(200)
        expect(response.parsed_body["actors"].size).to eq(2)
      end

      context "when an actor is tombstoned" do
        before { actor2.update(ap_type: DiscourseActivityPub::AP::Object::Tombstone.type) }

        it "returns the actor" do
          get "/admin/plugins/ap/actor.json?model_type=category"
          expect(response.status).to eq(200)
          expect(response.parsed_body["actors"].size).to eq(2)
        end
      end
    end
  end

  describe "#show" do
    context "with an administratable actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_group) }

      it "returns the actor" do
        get "/admin/plugins/ap/actor/#{actor.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["id"]).to eq(actor.id)
      end

      context "when it is tombstoned" do
        before { actor.update(ap_type: DiscourseActivityPub::AP::Object::Tombstone.type) }

        it "returns the actor" do
          get "/admin/plugins/ap/actor/#{actor.id}.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["id"]).to eq(actor.id)
          expect(response.parsed_body["ap_type"]).to eq("Tombstone")
        end
      end
    end

    context "with a non-administrable actor" do
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_person) }

      it "returns an actor not found error" do
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

    context "with a category" do
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

    context "with a tag" do
      let!(:tag) { Fabricate(:tag) }

      context "without a username" do
        it "returns a 400" do
          post "/admin/plugins/ap/actor.json",
               params: {
                 actor: {
                   model_type: "Tag",
                   model_name: tag.name,
                   model_id: tag.id,
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
                   model_type: "Tag",
                   model_id: tag.id,
                   model_name: tag.name,
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
                   model_type: "Tag",
                   model_id: tag.id,
                   model_name: tag.name,
                   username: "new_actor",
                   default_visibility: "public",
                   publication_type: "full_topic",
                 },
               }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["username"]).to eq("new_actor")
          expect(response.parsed_body["actor"]["model"]["id"]).to eq(tag.id)
          expect(response.parsed_body["actor"]["default_visibility"]).to eq("public")
          expect(response.parsed_body["actor"]["publication_type"]).to eq("full_topic")
        end
      end
    end
  end

  describe "#update" do
    context "when the actor cant be found" do
      it "returns a 404" do
        put "/admin/plugins/ap/actor/30.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(actor_error("actor_not_found"))
      end
    end

    context "with a category actor" do
      let!(:category) { Fabricate(:category) }
      let!(:actor) do
        Fabricate(:discourse_activity_pub_actor_group, model: category, enabled: true)
      end

      context "with private visibility and full topic publication" do
        it "returns a 400" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
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
        it "returns an updated actor" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
                  username: "new_actor",
                },
              }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["username"]).to eq("new_actor")
        end
      end

      context "with valid params" do
        it "returns an updated actor" do
          put "/admin/plugins/ap/actor/#{actor.id}.json", params: { actor: { name: "New name" } }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["name"]).to eq("New name")
        end
      end
    end

    context "with a tag actor" do
      let!(:tag) { Fabricate(:tag) }
      let!(:actor) { Fabricate(:discourse_activity_pub_actor_group, model: tag, enabled: true) }

      context "with private visibility and full topic publication" do
        it "returns a 400" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
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
        it "returns an updated actor" do
          put "/admin/plugins/ap/actor/#{actor.id}.json",
              params: {
                actor: {
                  username: "new_actor",
                },
              }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["username"]).to eq("new_actor")
        end
      end

      context "with valid params" do
        it "returns an updated actor" do
          put "/admin/plugins/ap/actor/#{actor.id}.json", params: { actor: { name: "New name" } }
          expect(response.status).to eq(200)
          expect(response.parsed_body["actor"]["name"]).to eq("New name")
        end
      end
    end
  end

  describe "#delete" do
    before do
      Jobs.run_immediately!
      freeze_time
    end
    after { unfreeze_time }

    context "when the actor cant be found" do
      it "returns a 404" do
        delete "/admin/plugins/ap/actor/30.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(actor_error("actor_not_found"))
      end
    end

    context "with a supported actor" do
      let!(:category) { Fabricate(:category) }
      let!(:group_actor) do
        Fabricate(:discourse_activity_pub_actor_group, model: category, enabled: true)
      end
      let!(:group_note) do
        Fabricate(:discourse_activity_pub_object_note, attributed_to: group_actor)
      end
      let!(:topic) { Fabricate(:topic, category: category) }
      let!(:post) { Fabricate(:post, topic: topic) }
      let!(:person_actor) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:person_note) do
        Fabricate(:discourse_activity_pub_object_note, attributed_to: person_actor, model: post)
      end
      let!(:person_note_announce) do
        Fabricate(
          :discourse_activity_pub_activity_announce,
          object: person_note,
          actor: group_actor,
        )
      end

      context "when not tombstoned" do
        it "tombstones the actor" do
          delete "/admin/plugins/ap/actor/#{group_actor.id}.json"
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubActor.unscoped.find(group_actor.id).ap_type).to eq("Tombstone")
        end

        it "destroys objects attributed to the actor" do
          delete "/admin/plugins/ap/actor/#{group_actor.id}.json"
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubObject.unscoped.find(group_note.id).ap_type).to eq("Tombstone")
        end

        it "does not tombstone objects announced by the actor" do
          delete "/admin/plugins/ap/actor/#{group_actor.id}.json"
          expect(response.status).to eq(200)
          expect(person_note.reload.ap_type).to eq("Note")
        end
      end

      context "when tombstoned" do
        before { group_actor.update(ap_type: "Tombstone") }

        it "destroys the actor" do
          delete "/admin/plugins/ap/actor/#{group_actor.id}.json"
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubActor.unscoped.exists?(group_actor.id)).to eq(false)
        end

        it "destroys objects attributed to the actor" do
          delete "/admin/plugins/ap/actor/#{group_actor.id}.json"
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubObject.unscoped.exists?(group_note.id)).to eq(false)
        end

        it "does not destroy objects announced by the actor" do
          delete "/admin/plugins/ap/actor/#{group_actor.id}.json"
          expect(response.status).to eq(200)
          expect(person_note.reload.ap_type).to eq("Note")
        end
      end
    end
  end

  describe "#restore" do
    context "when the actor cant be found" do
      it "returns a 404" do
        post "/admin/plugins/ap/actor/30/restore.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(actor_error("actor_not_found"))
      end
    end

    context "with a supported actor" do
      let!(:category) { Fabricate(:category) }
      let!(:group_actor) do
        Fabricate(:discourse_activity_pub_actor_group, model: category, enabled: true)
      end
      let!(:group_note) do
        Fabricate(:discourse_activity_pub_object_note, attributed_to: group_actor)
      end
      let!(:topic) { Fabricate(:topic, category: category) }
      let!(:post1) { Fabricate(:post, topic: topic) }
      let!(:person_actor) { Fabricate(:discourse_activity_pub_actor_person) }
      let!(:person_note) do
        Fabricate(:discourse_activity_pub_object_note, attributed_to: person_actor, model: post1)
      end
      let!(:person_note_announce) do
        Fabricate(
          :discourse_activity_pub_activity_announce,
          object: person_note,
          actor: group_actor,
        )
      end

      context "when not tombstoned" do
        it "returns a 400" do
          post "/admin/plugins/ap/actor/#{group_actor.id}/restore.json"
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(actor_error("actor_cant_be_restored"))
        end
      end

      context "when tombstoned" do
        before do
          group_actor.update(ap_type: "Tombstone", ap_former_type: "Group")
          group_note.update(ap_type: "Tombstone", ap_former_type: "Article")
        end

        it "restores the actor" do
          post "/admin/plugins/ap/actor/#{group_actor.id}/restore.json"
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubActor.find(group_actor.id).ap_type).to eq("Group")
        end

        it "restores objects attributed to the actor" do
          post "/admin/plugins/ap/actor/#{group_actor.id}/restore.json"
          expect(response.status).to eq(200)
          expect(DiscourseActivityPubObject.find(group_note.id).ap_type).to eq("Article")
        end
      end
    end
  end
end
