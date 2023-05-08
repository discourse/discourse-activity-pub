import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Category from "discourse/models/category";

acceptance("Discourse Activity Pub | Discovery", function (needs) {
  needs.user();
  needs.site({ activity_pub_enabled: true });

  test("with a non-category route", async function (assert) {
    await visit("/latest");

    assert.ok(
      !exists(".activity-pub-discovery"),
      "the discovery button is not visible"
    );
  });

  test("with a category without show handle enabled", async function (assert) {
    const category = Category.findById(2);
    category.set("activity_pub_show_handle", false);

    await visit(category.url);

    assert.ok(
      !exists(".activity-pub-discovery"),
      "the discovery button is not visible"
    );
  });

  test("with a category with show handle enabled", async function (assert) {
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
});
