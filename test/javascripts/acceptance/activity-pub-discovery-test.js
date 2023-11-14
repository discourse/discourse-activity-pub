import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Category from "discourse/models/category";
import { default as CategoryFollowers } from "../fixtures/category-followers-fixtures";
import I18n from "I18n";

const followersPath = "/ap/category/2/followers";

acceptance(
  "Discourse Activity Pub | Discovery without site enabled",
  function (needs) {
    needs.user();
    needs.site({ activity_pub_enabled: false });

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
    needs.site({ activity_pub_enabled: true });
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
      });

      await visit(category.url);

      assert.ok(
        exists(".activity-pub-category-nav.visible"),
        "the activitypub nav button is visible"
      );

      await click(".activity-pub-category-nav");

      assert.ok(
        exists(".activity-pub-category-banner"),
        "the activitypub category banner is visible"
      );
      assert.ok(
        exists(".activity-pub-category-banner"),
        "the activitypub category banner is visible"
      );
      assert.ok(
        query(".activity-pub-category-banner-text").innerText,
        I18n.t("`discourse_activity_pub.banner.text"),
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
  "Discourse Activity Pub | Discovery activitypub category route without followers",
  function (needs) {
    needs.user();
    needs.site({ activity_pub_enabled: true });
    needs.pretender((server, helper) => {
      server.get(`${followersPath}.json`, () =>
        helper.response({ followers: [] })
      );
    });

    test("with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_ready", true);

      await visit(followersPath);

      assert.ok(
        !exists(".activity-pub-followers"),
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
  "Discourse Activity Pub | Discovery activitypub category route with followers",
  function (needs) {
    needs.user();
    needs.site({ activity_pub_enabled: true });
    needs.pretender((server, helper) => {
      const path = `${followersPath}.json`;
      server.get(path, () => helper.response(CategoryFollowers[path]));
    });

    test("with activity pub ready", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_ready", true);

      await visit(followersPath);

      assert.ok(
        exists(".activity-pub-followers"),
        "the activitypub followers table is visible"
      );
      assert.strictEqual(
        document.querySelectorAll(".activity-pub-follower").length,
        2,
        "followers are visible"
      );
      assert.ok(
        query(".activity-pub-follower-image img").src.includes(
          "/images/avatar.png"
        ),
        "follower image is visible"
      );
      assert.equal(
        query(".activity-pub-follower-name").innerText,
        "Angus",
        "follower name is visible"
      );
      assert.equal(
        query(".activity-pub-follower-handle").innerText,
        "@angus_ap@test.local",
        "follower handle is visible"
      );
      assert.ok(
        query(".activity-pub-follower-user a.avatar").href.includes("/u/angus"),
        "follower user avatar is visible"
      );
      assert.equal(
        query(".activity-pub-followed-at").innerText,
        "Feb 8, '13",
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
          name: category.name,
        }),
        "activitypub modal has the right title"
      );
    });
  }
);
