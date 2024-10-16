import { click, currentURL, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "I18n";
import { default as Actors } from "../fixtures/actors-fixtures";
import { default as Followers } from "../fixtures/followers-fixtures";
import { default as Follows } from "../fixtures/follows-fixtures";
import { default as SiteActors } from "../fixtures/site-actors-fixtures";

const actorPath = `/ap/local/actor/2`;
const followsPath = `${actorPath}/follows`;
const followersPath = `${actorPath}/followers`;

acceptance(
  "Discourse Activity Pub | Discovery without site enabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: false,
      activity_pub_publishing_enabled: false,
      activity_pub_actors: SiteActors,
    });

    test("with a non-category route", async function (assert) {
      await visit("/latest");

      assert.ok(
        !exists(".activity-pub-discovery"),
        "the discovery button is not visible"
      );
    });

    test("with a category route without category enabled", async function (assert) {
      const category = Category.findById(2);

      await visit(category.url);

      assert.ok(
        !exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category route with category enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_enabled", true);

      await visit(category.url);

      assert.ok(
        !exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery with site enabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followersPath}.json`, () =>
        helper.response(Followers[followersPath])
      );
      server.get("/tag/:tag_name/notifications", (request) => {
        return helper.response({
          tag_notification: {
            id: request.params.tag_name,
            notification_level: 1,
          },
        });
      });
      server.get("/tag/:tag_name/l/latest.json", (request) => {
        return helper.response({
          users: [],
          primary_groups: [],
          topic_list: {
            can_create_topic: true,
            draft: null,
            draft_key: "new_topic",
            draft_sequence: 1,
            per_page: 30,
            tags: [
              {
                id: 1,
                name: request.params.tag_name,
                topic_count: 1,
              },
            ],
            topics: [],
          },
        });
      });
    });

    test("with a non-category route", async function (assert) {
      Site.current().set("activity_pub_actors", SiteActors);

      await visit("/latest");

      assert.ok(
        !exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category without an activity pub actor", async function (assert) {
      const category = Category.findById(2);

      Site.current().set("activity_pub_actors", []);

      await visit(category.url);

      assert.ok(
        !exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category with an activity pub actor", async function (assert) {
      const category = Category.findById(2);

      Site.current().set("activity_pub_actors", SiteActors);

      await visit(category.url);

      assert.ok(
        exists(".activity-pub-route-nav.visible"),
        "the activitypub nav button is visible"
      );

      await click(".activity-pub-route-nav");

      assert.ok(
        exists(".activity-pub-banner"),
        "the activitypub category banner is visible"
      );
      assert.strictEqual(
        query(".activity-pub-banner-text .desktop").textContent.trim(),
        I18n.t("discourse_activity_pub.banner.text", {
          model_name: "Cat 2",
        }),
        "shows the right banner text"
      );

      await triggerEvent(".fk-d-tooltip__trigger", "mousemove");
      assert.equal(
        query(".fk-d-tooltip__inner-content").textContent.trim(),
        I18n.t("discourse_activity_pub.banner.public_first_post"),
        "shows the right category banner tip"
      );
    });

    test("when routing from a category with an actor to one without", async function (assert) {
      const category = Category.findById(2);
      Site.current().set("activity_pub_actors", SiteActors);

      await visit(category.url);

      assert.ok(
        exists(".activity-pub-route-nav.visible"),
        "the activitypub nav button is visible"
      );

      const categoryDrop = selectKit(".category-drop");
      await categoryDrop.expand();
      await categoryDrop.selectRowByValue(7);

      assert.ok(
        !exists(".activity-pub-route-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });

    test("when routing from a tag with an actor to one without", async function (assert) {
      Site.current().setProperties({
        activity_pub_actors: SiteActors,
        top_tags: ["monkey", "dog"],
      });

      await visit("/tag/monkey");

      assert.ok(
        exists(".activity-pub-route-nav.visible"),
        "the activitypub nav button is visible"
      );

      const tagDrop = selectKit(".tag-drop");
      await tagDrop.expand();
      await tagDrop.selectRowByName("dog");

      assert.ok(
        !exists(".activity-pub-route-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery with publishing disabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: false,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followsPath}.json`, () => helper.response({ follows: [] }));
    });

    test("with a category route with activity pub ready", async function (assert) {
      const category = Category.findById(2);

      await visit(category.url);
      await click(".activity-pub-route-nav");

      assert.ok(
        !exists(".activity-pub-banner"),
        "the activitypub banner is not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub followers route with publishing disabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: false,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get("/ap/local/actor/1", () =>
        helper.response(Actors["/ap/local/actor/1"])
      );
    });

    test("returns 404", async function (assert) {
      await visit("/ap/local/actor/1/followers");
      assert.strictEqual(currentURL(), "/404");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub followers route without followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followersPath}.json`, () =>
        helper.response({ followers: [] })
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit(followersPath);

      assert.ok(
        !exists(".activity-pub-follow-table.followers"),
        "the activitypub followers table is not visible"
      );
      assert.equal(
        query(".activity-pub-followers-container").innerText,
        I18n.t("search.no_results"),
        "no results shown"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub followers route with followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followersPath}.json`, () =>
        helper.response(Followers[followersPath])
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit(followersPath);

      assert.ok(
        exists(".activity-pub-follow-table.followers"),
        "the activitypub followers table is visible"
      );
      assert.strictEqual(
        document.querySelectorAll(".activity-pub-follow-table-row").length,
        2,
        "followers are visible"
      );
      assert.ok(
        query(".activity-pub-actor-image img").src.includes(
          "/images/avatar.png"
        ),
        "follower image is visible"
      );
      assert.equal(
        query(".activity-pub-actor-name").innerText,
        "Angus",
        "follower name is visible"
      );
      assert.equal(
        query(".activity-pub-actor-handle").innerText,
        "@angus_ap@test.local",
        "follower handle is visible"
      );
      assert.ok(
        query(".activity-pub-follow-table-user a.avatar").href.includes(
          "/u/angus"
        ),
        "follower user avatar is visible"
      );
      assert.equal(
        query(".activity-pub-follow-table-followed-at").innerText,
        "Feb 8, 2013",
        "follower followed at is visible"
      );
      assert.ok(
        exists(".activity-pub-follow-btn"),
        "the activitypub follow btn is visible"
      );
      await click(".activity-pub-follow-btn");
      assert.ok(
        exists(".modal.activity-pub-follow-modal"),
        "it shows the activitypub follow modal"
      );
      assert.equal(
        query("#discourse-modal-title").innerText,
        I18n.t("discourse_activity_pub.follow.title", {
          actor: "Cat 2",
        }),
        "activitypub modal has the right title"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub follows route with no create follow permission",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get("/ap/local/actor/1", () =>
        helper.response(Actors["/ap/local/actor/1"])
      );
    });

    test("returns 404", async function (assert) {
      await visit("/ap/local/actor/1/follows");
      assert.strictEqual(currentURL(), "/404");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub subcategory follows route with edit permission",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get("/ap/local/actor/3", () =>
        helper.response(Actors["/ap/local/actor/3"])
      );
      server.get(`/ap/local/actor/3/follows.json`, () =>
        helper.response({ follows: [] })
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit("/ap/local/actor/3/follows");

      assert.ok(
        exists(".activity-pub-follows-container"),
        "the activitypub follows route is visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub category follows route with edit permission with followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followsPath}.json`, () =>
        helper.response(Follows[followsPath])
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit(followsPath);

      assert.ok(
        exists(".activity-pub-follow-table.follows"),
        "the activitypub follows table is visible"
      );
      assert.strictEqual(
        document.querySelectorAll(".activity-pub-follow-table-row").length,
        2,
        "follows are visible"
      );
      assert.ok(
        query(".activity-pub-actor-image img").src.includes(
          "/images/avatar.png"
        ),
        "follower image is visible"
      );
      assert.equal(
        query(".activity-pub-actor-name").innerText,
        "Angus",
        "follower name is visible"
      );
      assert.equal(
        query(".activity-pub-actor-handle").innerText,
        "@angus_ap@test.local",
        "follow handle is visible"
      );
      assert.ok(
        query(".activity-pub-follow-table-user a.avatar").href.includes(
          "/u/angus"
        ),
        "follow user avatar is visible"
      );
      assert.equal(
        query(".activity-pub-follow-table-followed-at").innerText,
        "Feb 8, 2013",
        "follower followed at is visible"
      );

      assert.ok(
        exists(".activity-pub-actor-follow-btn"),
        "the activitypub actor follow btn is visible"
      );
      await click(".activity-pub-actor-follow-btn");
      assert.ok(
        exists(".modal.activity-pub-actor-follow-modal"),
        "it shows the activitypub actor follow modal"
      );
      assert.equal(
        query("#discourse-modal-title").innerText,
        I18n.t("discourse_activity_pub.actor_follow.title", {
          actor: "Cat 2",
        }),
        "activitypub actor follow modal has the right title"
      );

      assert.ok(
        exists(".activity-pub-actor-unfollow-btn"),
        "the activitypub actor unfollow btn is visible"
      );
      await click(".activity-pub-actor-unfollow-btn");
      assert.ok(
        exists(".modal.activity-pub-actor-unfollow-modal"),
        "it shows the activitypub actor unfollow modal"
      );
      assert.equal(
        query("#discourse-modal-title").innerText,
        I18n.t("discourse_activity_pub.actor_unfollow.modal_title", {
          actor: "Cat 2",
        }),
        "activitypub actor unfollow modal has the right title"
      );
    });
  }
);
