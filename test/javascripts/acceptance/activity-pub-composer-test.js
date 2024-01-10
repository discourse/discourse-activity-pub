import { click, visit } from "@ember/test-helpers";
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

  test("with a category with activity pub ready", async function (assert) {
    Site.current().setProperties({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
    });
    Category.findById(2).setProperties({
      activity_pub_ready: true,
      activity_pub_default_visibility: "public",
    });

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit("#reply-control .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert.ok(
      exists("#reply-control .activity-pub-status"),
      "the status label is visible"
    );
    assert.strictEqual(
      query("#reply-control .activity-pub-status .label").innerText.trim(),
      I18n.t("discourse_activity_pub.visibility.label.public"),
      "the status label has the right text"
    );
  });

  test("when the plugin is disabled", async function (assert) {
    Site.current().set("activity_pub_enabled", false);
    Category.findById(2).set("activity_pub_ready", true);

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
