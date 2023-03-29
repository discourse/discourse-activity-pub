import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Category from "discourse/models/category";
import Site from "discourse/models/site";

acceptance("Discourse Activity Pub | composer", function (needs) {
  needs.user();

  test("without a category", async function (assert) {
    Site.current().set("activity_pub_enabled", true);

    await visit("/");
    await click("#create-topic");

    assert.ok(
      !exists("#reply-control .activity-pub-status"),
      "the status label is not visible"
    );
  });

  test("with a category without show status enabled", async function (assert) {
    Site.current().set("activity_pub_enabled", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit("#reply-control .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert.ok(
      !exists("#reply-control .activity-pub-status"),
      "the status label is not visible"
    );
  });

  test("with a category with show status enabled", async function (assert) {
    Site.current().set("activity_pub_enabled", true);
    Category.findById(2).set("activity_pub_show_status", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit("#reply-control .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert.ok(
      exists("#reply-control .activity-pub-status"),
      "the status label is visible"
    );
  });

  test("when the plugin is disabled", async function (assert) {
    Site.current().set("activity_pub_enabled", false);
    Category.findById(2).set("activity_pub_show_status", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit("#reply-control .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert.ok(
      !exists("#reply-control .activity-pub-status"),
      "the status label is not visible"
    );
  });
});
