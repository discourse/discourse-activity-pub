import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { default as AdminActors } from "../fixtures/admin-actors-fixtures";

const categoryActors =
  AdminActors["/admin/plugins/ap/actor?model_type=category"];

acceptance(
  "Discourse Activity Pub | Admin | ActivityPub disabled",
  function (needs) {
    needs.user({ admin: true });
    needs.site({
      activity_pub_enabled: false,
      activity_pub_publishing_enabled: false,
    });
    needs.pretender((server, helper) => {
      server.get("/admin/plugins/ap/actor", () =>
        helper.response(categoryActors)
      );
    });

    test("returns 404", async function (assert) {
      await visit("/admin/plugins/ap/actor");
      assert.strictEqual(currentURL(), "/404");
    });
  }
);

acceptance("Discourse Activity Pub | Admin | Categories", function (needs) {
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
    activity_pub_publishing_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/plugins/ap/actor", () =>
      helper.response(categoryActors)
    );
  });

  test("lists category actors", async function (assert) {
    await visit("/admin/plugins/ap/actor");
    assert.ok(
      exists(".activity-pub-actor-table"),
      "the actors table is visible"
    );
    assert.strictEqual(
      document.querySelectorAll(".activity-pub-actor-table-row").length,
      2,
      "actors are visible"
    );
    assert.ok(
      exists(".activity-pub-actor-edit-btn"),
      "the actor edit btn is visible"
    );
    await click(".activity-pub-actor-edit-btn");
    assert.ok(
      exists(".admin-plugins.activity-pub.actor-show"),
      "it routes to actor show"
    );
  });
});

acceptance("Discourse Activity Pub | Admin | New Actor", function (needs) {
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
    activity_pub_publishing_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/plugins/ap/actor/new", () =>
      helper.response(categoryActors)
    );
  });

  test("creates a new actor", async function (assert) {
    await visit("/admin/plugins/ap/actor/new");

    assert.ok(
      exists(".activity-pub-actor-add"),
      "add actor container is visible"
    );
    assert.ok(
      exists(".activity-pub-new-actor-model"),
      "actor model controls are visible"
    );

    const modelTypes = selectKit(".activity-pub-model-type-chooser");
    await modelTypes.expand();
    await modelTypes.selectRowByValue("category");

    assert.ok(
      exists(".activity-pub-category-chooser"),
      "activity pub category chooser is visible"
    );

    const categories = selectKit(".activity-pub-category-chooser");
    await categories.expand();
    await categories.selectRowByValue(6);

    assert.ok(
      exists(".activity-pub-actor-form"),
      "activity pub actor form is visible"
    );

    const actor = {
      username: "ap_username",
      name: "AP name",
      default_visibility: "public",
      post_object_type: "Article",
      publication_type: "full_topic",
      model_type: "Category",
      model_id: "6",
    };

    await fillIn("#activity-pub-username", actor.username);
    await fillIn("#activity-pub-name", actor.name);

    const visibilities = selectKit(".activity-pub-visibility-dropdown");
    await visibilities.expand();
    await visibilities.selectRowByValue(actor.default_visibility);

    const postObjectTypes = selectKit(
      ".activity-pub-post-object-type-dropdown"
    );
    await postObjectTypes.expand();
    await postObjectTypes.selectRowByValue(actor.post_object_type);

    const publicationTypes = selectKit(
      ".activity-pub-publication-type-dropdown"
    );
    await publicationTypes.expand();
    await publicationTypes.selectRowByValue(actor.publication_type);

    const createdActor = {
      ...{ id: 3 },
      ...actor,
    };

    pretender.post("/admin/plugins/ap/actor", (request) => {
      const body = parsePostData(request.requestBody);
      Object.keys(actor).forEach((attr) => {
        assert.strictEqual(
          body.actor[attr],
          actor[attr],
          `it posts the correct ${attr}`
        );
      });
      return response({ success: true, actor: createdActor });
    });

    pretender.get(`/admin/plugins/ap/actor/${createdActor.id}`, () => {
      return response(createdActor);
    });

    await click(".activity-pub-save-actor");
  });

  test("creates a new actor with a tag model", async function (assert) {
    await visit("/admin/plugins/ap/actor/new");

    assert.ok(
      exists(".activity-pub-actor-add"),
      "add actor container is visible"
    );
    assert.ok(
      exists(".activity-pub-new-actor-model"),
      "actor model controls are visible"
    );

    const modelTypes = selectKit(".activity-pub-model-type-chooser");
    await modelTypes.expand();
    await modelTypes.selectRowByValue("tag");

    const tags = selectKit(".activity-pub-actor-add .tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    assert.ok(
      exists(".activity-pub-actor-form"),
      "activity pub actor form is visible"
    );

    const actor = {
      username: "ap_monkey",
      name: "AP monkey",
      default_visibility: "public",
      post_object_type: "Article",
      publication_type: "full_topic",
      model_type: "Tag",
      model_name: "monkey",
    };

    await fillIn("#activity-pub-username", actor.username);
    await fillIn("#activity-pub-name", actor.name);

    const visibilities = selectKit(".activity-pub-visibility-dropdown");
    await visibilities.expand();
    await visibilities.selectRowByValue(actor.default_visibility);

    const postObjectTypes = selectKit(
      ".activity-pub-post-object-type-dropdown"
    );
    await postObjectTypes.expand();
    await postObjectTypes.selectRowByValue(actor.post_object_type);

    const publicationTypes = selectKit(
      ".activity-pub-publication-type-dropdown"
    );
    await publicationTypes.expand();
    await publicationTypes.selectRowByValue(actor.publication_type);

    const createdActor = {
      ...{ id: 5 },
      ...actor,
    };

    pretender.post("/admin/plugins/ap/actor", (request) => {
      const body = parsePostData(request.requestBody);
      Object.keys(actor).forEach((attr) => {
        assert.strictEqual(
          body.actor[attr],
          actor[attr],
          `it posts the correct ${attr}`
        );
      });
      return response({ success: true, actor: createdActor });
    });

    pretender.get(`/admin/plugins/ap/actor/${createdActor.id}`, () => {
      return response(createdActor);
    });

    await click(".activity-pub-save-actor");

    // pauseTest();
  });
});

acceptance("Discourse Activity Pub | Admin | Edit Actor", function (needs) {
  const actor = categoryActors.actors[0];
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
    activity_pub_publishing_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get(`/admin/plugins/ap/actor/${actor.id}`, () =>
      helper.response(actor)
    );
  });

  test("edits an actor", async function (assert) {
    await visit(`/admin/plugins/ap/actor/${actor.id}`);

    assert.ok(
      exists(".activity-pub-actor-edit"),
      "edit actor container is visible"
    );
    assert.ok(exists(".activity-pub-actor-model"), "actor model is visible");
    assert.strictEqual(
      query(".activity-pub-handle .handle").innerText.trim(),
      actor.handle,
      "shows the right handle"
    );

    const updates = {
      name: "Updated name",
    };
    const updatedActor = {
      ...actor,
      ...updates,
    };

    await fillIn("#activity-pub-name", updatedActor.name);

    pretender.put(`/admin/plugins/ap/actor/${updatedActor.id}`, (request) => {
      const body = parsePostData(request.requestBody);
      assert.strictEqual(
        body.actor.name,
        updatedActor.name,
        `it posts the correct update`
      );
      return response({ success: true, actor: updatedActor });
    });

    await click(".activity-pub-save-actor");
  });
});
