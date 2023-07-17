import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
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
    Category.findById(2).setProperties({
      activity_pub_show_status: true,
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
    assert.ok(
      exists("#reply-control .activity-pub-visibility-dropdown"),
      "the visibility dropdown is visible"
    );
    assert.strictEqual(
      query(
        "#reply-control .activity-pub-visibility-dropdown .select-kit-header-wrapper .name"
      ).innerText.trim(),
      I18n.t("discourse_activity_pub.visibility.public.label"),
      "has the right default visibility"
    );

    const dropdown = selectKit(
      "#reply-control .activity-pub-visibility-dropdown"
    );
    await dropdown.expand();
    await dropdown.selectRowByValue("private");

    assert.strictEqual(
      query(
        "#reply-control .activity-pub-visibility-dropdown .select-kit-header-wrapper .name"
      ).innerText.trim(),
      I18n.t("discourse_activity_pub.visibility.private.label"),
      "successfully changes the visibility"
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
