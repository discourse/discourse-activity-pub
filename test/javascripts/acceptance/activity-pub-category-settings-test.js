import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Site from "discourse/models/site";

function setSite(context, attrs = {}) {
  context.siteSettings.activity_pub_enabled = attrs.activity_pub_enabled;
  context.siteSettings.login_required = !attrs.activity_pub_publishing_enabled;
  Site.current().setProperties({
    activity_pub_enabled: attrs.activity_pub_enabled,
    activity_pub_publishing_enabled: attrs.activity_pub_publishing_enabled,
  });
}

acceptance(
  "Discourse Activity Pub | Category Settings with plugin disabled",
  function (needs) {
    needs.user({ admin: true });

    test("does not display any ActivityPub settings", async function (assert) {
      setSite(this, { activity_pub_enabled: false });
      await visit("/new-category");
      await click(".edit-category-settings");

      assert.ok(exists(".edit-category-tab-settings"));
      assert.ok(
        !exists(".activity-pub-category-settings-title"),
        "activity pub settings are not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Category Settings with plugin enabled",
  function (needs) {
    needs.user({ admin: true });

    test("with category enabled", async function (assert) {
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });
      await visit("/new-category");
      await click(".edit-category-settings");

      assert.ok(
        exists(".activity-pub-enabled"),
        "activity pub enabled setting is visible"
      );

      await click(".activity-pub-enabled input");

      assert.ok(
        !exists(".activity-pub-site-setting.activity-pub-enabled"),
        "activity pub enabled site setting notice is not visible"
      );
      assert.ok(
        !exists(".activity-pub-site-setting.login-required"),
        "login required site setting notice is not visible"
      );
      assert.ok(
        exists(".activity-pub-username"),
        "activity pub username setting is visible"
      );
      assert.ok(
        exists(".activity-pub-name"),
        "activity pub name setting is visible"
      );
      assert.ok(
        exists(".activity-pub-default-visibility"),
        "activity pub default visibility setting is visible"
      );
      assert.ok(
        exists(".activity-pub-post-object-type"),
        "activity pub post object type setting is visible"
      );
      assert.ok(
        exists(".activity-pub-publication-type"),
        "activity pub publication type setting is visible"
      );
    });

    test("with category disabled", async function (assert) {
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });
      await visit("/new-category");
      await click(".edit-category-settings");

      assert.ok(
        exists(".activity-pub-enabled"),
        "activity pub enabled setting is visible"
      );
      assert.ok(
        !exists(".activity-pub-site-setting.activity-pub-enabled"),
        "activity pub enabled site setting notice is not visible"
      );
      assert.ok(
        !exists(".activity-pub-site-setting.login-required"),
        "login required site setting notice is not visible"
      );
      assert.ok(
        exists(".activity-pub-username"),
        "activity pub username setting is visible"
      );
      assert.ok(
        exists(".activity-pub-name"),
        "activity pub name setting is visible"
      );
      assert.ok(
        exists(".activity-pub-default-visibility"),
        "activity pub default visibility setting is visible"
      );
      assert.ok(
        exists(".activity-pub-post-object-type"),
        "activity pub post object type setting is visible"
      );
      assert.ok(
        exists(".activity-pub-publication-type"),
        "activity pub publication type setting is visible"
      );
    });

    test("with login required and category enabled", async function (assert) {
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: false,
      });
      await visit("/new-category");
      await click(".edit-category-settings");
      await click(".activity-pub-enabled input");

      assert.ok(
        exists(".activity-pub-category-settings-title"),
        "activity pub settings are visible"
      );
      assert.ok(
        exists(".activity-pub-site-setting.activity-pub-enabled"),
        "activity pub enabled site setting notice is visible"
      );
      assert.ok(
        exists(".activity-pub-site-setting.login-required"),
        "login required site setting notice is visible"
      );
      assert.ok(
        exists(".activity-pub-username"),
        "activity pub username setting is visible"
      );
      assert.ok(
        exists(".activity-pub-name"),
        "activity pub name setting is visible"
      );
    });

    test("with login required and category disabled", async function (assert) {
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: false,
      });
      await visit("/new-category");
      await click(".edit-category-settings");

      assert.ok(
        exists(".activity-pub-category-settings-title"),
        "activity pub settings are visible"
      );
      assert.ok(
        !exists(".activity-pub-site-setting"),
        "activity pub site settings are not visible"
      );
    });
  }
);
