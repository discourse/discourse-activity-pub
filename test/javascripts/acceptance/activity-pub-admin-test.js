import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AdminActors from "../fixtures/admin-actors-fixtures";
import Logs from "../fixtures/logs-fixtures";
import SiteActors from "../fixtures/site-actors-fixtures";

const categoryActors =
  AdminActors["/admin/plugins/ap/actor?model_type=category"];
const tagActors = AdminActors["/admin/plugins/ap/actor?model_type=tag"];

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

acceptance("Discourse Activity Pub | Admin | Index", function (needs) {
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
    activity_pub_publishing_enabled: true,
  });

  test("lists category actors", async function (assert) {
    pretender.get("/admin/plugins/ap/actor", (request) => {
      if (request.queryParams.model_type === "category") {
        return response(categoryActors);
      } else {
        return response(tagActors);
      }
    });

    await visit("/admin/plugins/ap/actor");
    assert
      .dom(".activity-pub-actor-table")
      .exists("the actors table is visible");
    assert
      .dom(".activity-pub-actor-table-row")
      .exists({ count: 2 }, "actors are visible");
    assert
      .dom(".activity-pub-actor-edit-btn")
      .exists("the actor edit btn is visible");
    await click(".activity-pub-actor-edit-btn");
    assert
      .dom(".admin-plugins.activity-pub.actor-show")
      .exists("routes to actor show");
  });

  test("actor controls", async function (assert) {
    let queryParams;
    pretender.get("/admin/plugins/ap/actor", (request) => {
      queryParams = request.queryParams;
      if (queryParams.model_type === "category") {
        return response(categoryActors);
      } else {
        return response(tagActors);
      }
    });
    pretender.get("/admin/plugins/ap/actor/new", (request) => {
      queryParams = request.queryParams;
      if (queryParams.model_type === "category") {
        return response(categoryActors);
      } else {
        return response(tagActors);
      }
    });

    await visit("/admin/plugins/ap/actor");
    assert
      .dom(".activity-pub-add-actor.category")
      .exists("the add category actor button is visible");
    await click(".activity-pub-add-actor");
    assert.strictEqual(
      queryParams.model_type,
      "category",
      "new actor model_type is correct"
    );

    await visit("/admin/plugins/ap/actor?model_type=tag");
    assert
      .dom(".activity-pub-add-actor.tag")
      .exists("the add tag actor button is visible");
    await click(".activity-pub-add-actor");
    assert.strictEqual(
      queryParams.model_type,
      "tag",
      "new actor model_type is correct"
    );
  });
});

acceptance("Discourse Activity Pub | Admin | New Actor", function (needs) {
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
    activity_pub_publishing_enabled: true,
    activity_pub_actors: cloneJSON(SiteActors),
  });
  needs.pretender((server, helper) => {
    server.get("/admin/plugins/ap/actor/new", () =>
      helper.response(categoryActors)
    );
  });

  test("creates a new actor", async function (assert) {
    await visit("/admin/plugins/ap/actor/new");

    assert
      .dom(".activity-pub-actor-add")
      .exists("add actor container is visible");
    assert
      .dom(".activity-pub-new-actor-model")
      .exists("actor model controls are visible");

    assert
      .dom(".activity-pub-category-chooser")
      .exists("activity pub category chooser is visible");

    const categories = selectKit(".activity-pub-category-chooser");
    await categories.expand();
    await categories.selectRowByValue(6);

    assert
      .dom(".activity-pub-actor-form")
      .exists("activity pub actor form is visible");

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
    await visit("/admin/plugins/ap/actor/new?model_type=tag");

    assert
      .dom(".activity-pub-actor-add")
      .exists("add actor container is visible");
    assert
      .dom(".activity-pub-new-actor-model")
      .exists("actor model controls are visible");

    const tags = selectKit(".activity-pub-actor-add .tag-chooser");
    await tags.expand();
    await tags.selectRowByName("dog");

    assert
      .dom(".activity-pub-actor-form")
      .exists("activity pub actor form is visible");

    const actor = {
      username: "ap_dog",
      name: "AP dog",
      default_visibility: "public",
      post_object_type: "Article",
      publication_type: "full_topic",
      model_type: "Tag",
      model_name: "dog",
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
      ...{ id: 5, enabled: true, ready: true, model: "dog" },
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

    const siteActors = Site.currentProp("activity_pub_actors");
    assert.true(
      siteActors.tag.some((a) => a.name === createdActor.name),
      "adds the actor to site actors"
    );
    assert
      .dom(".activity-pub-actor-status")
      .hasClass("active", "actor has the right status");
  });
});

acceptance("Discourse Activity Pub | Admin | Edit Actor", function (needs) {
  const actor = categoryActors.actors[0];
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
    activity_pub_publishing_enabled: true,
    activity_pub_actors: cloneJSON(SiteActors),
  });
  needs.pretender((server, helper) => {
    server.get(`/admin/plugins/ap/actor/${actor.id}`, () =>
      helper.response(actor)
    );
  });

  test("edits an actor", async function (assert) {
    await visit(`/admin/plugins/ap/actor/${actor.id}`);

    assert
      .dom(".activity-pub-actor-edit")
      .exists("edit actor container is visible");
    assert.dom(".activity-pub-actor-model").exists("actor model is visible");
    assert
      .dom(".activity-pub-handle .handle")
      .hasText(actor.handle, "shows the right handle");

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

    const siteActors = Site.currentProp("activity_pub_actors");
    assert.true(
      siteActors.category.some((a) => a.name === updatedActor.name),
      "updates the site actor"
    );
  });
});

acceptance("Discourse Activity Pub | Admin | Logs", function (needs) {
  needs.user({ admin: true });
  needs.site({
    activity_pub_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/plugins/ap/log.json", () =>
      helper.response(Logs["/admin/plugins/ap/log.json"])
    );
  });

  test("displays logs", async function (assert) {
    await visit("/admin/plugins/ap/log");

    assert.dom(".activity-pub-log-table").exists("log table is visible");
    assert
      .dom(".activity-pub-log-row")
      .exists({ count: 2 }, "logs are visible");
    assert
      .dom(
        ".activity-pub-log-row:nth-of-type(1) .activity-pub-log-show-json-btn"
      )
      .exists("shows show json button if log has json");
    assert
      .dom(
        ".activity-pub-log-row:nth-of-type(2) .activity-pub-log-show-json-btn"
      )
      .doesNotExist("does not show json button if log does not have json");

    await click(
      ".activity-pub-log-row:nth-of-type(1) .activity-pub-log-show-json-btn"
    );
    assert
      .dom(".modal.activity-pub-json-modal")
      .exists("shows the log json modal");
  });
});
