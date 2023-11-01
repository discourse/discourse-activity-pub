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
        !exists(".activity-pub-category-nav"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category route with category enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_enabled", true);

      await visit(category.url);

      assert.ok(
        !exists(".activity-pub-category-nav"),
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
        !exists(".activity-pub-category-nav"),
        "the activitypub nav button is not visible"
      );
    });

    test("with a category route with category enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_enabled", true);

      await visit(category.url);

      assert.ok(
        exists(".activity-pub-category-nav"),
        "the activitypub nav button is visible"
      );
    });

    test("with a category route without show handle enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_show_handle", false);

      await visit(category.url);

      assert.ok(
        !exists(".activity-pub-discovery"),
        "the discovery button is not visible"
      );
    });

    test("with a category route with show handle enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_show_handle", true);

      await visit(category.url);

      assert.ok(
        exists(".activity-pub-discovery"),
        "the discovery button is visible"
      );

      await click(".activity-pub-discovery button");

      assert.ok(
        exists(".activity-pub-discovery-dropdown"),
        "the discovery dropdown appears properly"
      );
      assert.ok(
        exists(".activity-pub-discovery-dropdown .activity-pub-handle"),
        "the handle appears in the dropdown"
      );

      await click(".d-header"); // click outside
      assert.ok(
        !exists(".activity-pub-discovery-dropdown"),
        "the discovery dropdown disappears properly"
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

    test("with category enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_enabled", true);

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

    test("with category enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_enabled", true);

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
        "angus_ap@test.local",
        "follower handle is visible"
      );
      assert.ok(
        query(".activity-pub-follower-user a.avatar").href.includes("/u/angus"),
        "follower user avatar is visible"
      );
      assert.equal(
        query(".activity-pub-followed-at").innerText,
        "Feb 9, '13",
        "follower followed at is visible"
      );
    });
  }
);
