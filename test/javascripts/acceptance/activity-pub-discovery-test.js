import { click, currentURL, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { default as CategoryFollowers } from "../fixtures/category-followers-fixtures";
import { default as CategoryFollows } from "../fixtures/category-follows-fixtures";

const followersPath = "/ap/category/2/followers";
const followsPath = "/ap/category/2/follows";

acceptance(
  "Discourse Activity Pub | Discovery without site enabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: false,
      activity_pub_publishing_enabled: false,
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
      server.get(`${followersPath}.json`, () =>
        helper.response({ followers: [] })
      );
    });

    test("with a non-category route", async function (assert) {
      await visit("/latest");

      assert.ok(
        !exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category route without activity pub ready", async function (assert) {
      const category = Category.findById(2);

      await visit(category.url);

      assert.ok(
        !exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category route with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.setProperties({
        activity_pub_ready: true,
        activity_pub_default_visibility: "public",
        activity_pub_publication_type: "full_topic",
        activity_pub_actor: {
          name: "Angus",
          handle: "angus@mastodon.pavilion.tech",
        },
      });

      await visit(category.url);

      assert.ok(
        exists(".activity-pub-category-route-nav.visible"),
        "the activitypub nav button is visible"
      );

      await click(".activity-pub-category-route-nav");

      assert.ok(
        exists(".activity-pub-category-banner"),
        "the activitypub category banner is visible"
      );
      assert.strictEqual(
        query(".activity-pub-category-banner-text").innerText,
        I18n.t("discourse_activity_pub.banner.text", {
          category_name: category.name,
        }),
        "shows the right category banner text"
      );

      await triggerEvent(".fk-d-tooltip__trigger", "mousemove");
      assert.equal(
        query(".fk-d-tooltip").innerText,
        I18n.t("discourse_activity_pub.banner.public_full_topic"),
        "shows the right category banner tip"
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
    });
    needs.pretender((server, helper) => {
      server.get(`/c/feature/find_by_slug.json`, () => {
        return helper.response(200, {
          category: {
            id: 2,
            name: "feature",
            slug: "feature",
            can_edit: true,
            activity_pub_ready: true,
            activity_pub_actor: {
              name: "Angus",
              handle: "angus@mastodon.pavilion.tech",
            },
          },
        });
      });
      const path = `${followsPath}.json`;
      server.get(path, () => helper.response(CategoryFollows[path]));
    });

    test("with a category route with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.setProperties({
        activity_pub_ready: true,
        activity_pub_actor: {
          name: "Angus",
          handle: "angus@mastodon.pavilion.tech",
        },
      });

      await visit(category.url);
      await click(".activity-pub-category-route-nav");

      assert.ok(
        !exists(".activity-pub-category-banner"),
        "the activitypub category banner is not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub category followers route with publishing disabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: false,
    });

    test("returns 404", async function (assert) {
      await visit(followersPath);
      assert.strictEqual(currentURL(), "/404");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub category followers route without followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get(`${followersPath}.json`, () =>
        helper.response({ followers: [] })
      );
    });

    test("with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.setProperties({
        activity_pub_ready: true,
        activity_pub_actor: {
          name: "Angus",
          handle: "angus@mastodon.pavilion.tech",
        },
      });

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
  "Discourse Activity Pub | Discovery activitypub category followers route with followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
    });
    needs.pretender((server, helper) => {
      const path = `${followersPath}.json`;
      server.get(path, () => helper.response(CategoryFollowers[path]));
    });

    test("with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.setProperties({
        activity_pub_ready: true,
        activity_pub_actor: {
          name: "Angus",
          handle: "angus@mastodon.pavilion.tech",
        },
      });

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
          actor: category.activity_pub_actor.name,
        }),
        "activitypub modal has the right title"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery activitypub category follows route with no edit permission",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get(`/c/feature/find_by_slug.json`, () => {
        return helper.response(200, {
          category: {
            id: 2,
            name: "feature",
            slug: "feature",
            can_edit: false,
            activity_pub_ready: true,
            activity_pub_actor: {
              name: "Angus",
              handle: "angus@mastodon.pavilion.tech",
            },
          },
        });
      });
    });

    test("returns 404", async function (assert) {
      await visit(followsPath);
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
    });
    needs.pretender((server, helper) => {
      server.get("/c/feature/spec/find_by_slug.json", () => {
        return helper.response(200, {
          category: {
            id: 26,
            name: "spec",
            slug: "spec",
            can_edit: true,
            activity_pub_ready: true,
            activity_pub_actor: {
              name: "Angus",
              handle: "angus@mastodon.pavilion.tech",
            },
          },
        });
      });
      const path = "/ap/category/26/follows.json";
      server.get(path, () => helper.response({}));
    });

    test("with activity pub ready", async function (assert) {
      const category = Category.findById(26);
      category.setProperties({
        activity_pub_ready: true,
        activity_pub_actor: {
          name: "Angus",
          handle: "angus@mastodon.pavilion.tech",
        },
      });

      await visit("/ap/category/26/follows");

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
    });
    needs.pretender((server, helper) => {
      server.get(`/c/feature/find_by_slug.json`, () => {
        return helper.response(200, {
          category: {
            id: 2,
            name: "feature",
            slug: "feature",
            can_edit: true,
          },
        });
      });
      const path = `${followsPath}.json`;
      server.get(path, () => helper.response(CategoryFollows[path]));
    });

    test("with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.setProperties({
        activity_pub_ready: true,
        activity_pub_actor: {
          name: "Angus",
          handle: "angus@mastodon.pavilion.tech",
        },
      });

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
          actor: category.activity_pub_actor.name,
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
          actor: category.activity_pub_actor.name,
        }),
        "activitypub actor unfollow modal has the right title"
      );
    });
  }
);
