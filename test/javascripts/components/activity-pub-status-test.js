import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import I18n from "I18n";

function setCategory(context, attrs = {}) {
  const categories = context.site.categoriesList;
  const category = categories.firstObject;

  Object.keys(attrs).forEach((key) => {
    category.set(key, attrs[key]);
  });

  context.set("category", category);
}

module(
  "Discourse Activity Pub | Component | activity-pub-status",
  function (hooks) {
    setupRenderingTest(hooks);
    const template = hbs`<ActivityPubStatus @model={{this.category}} @modelType="category" />`;

    test("with login required enabled", async function (assert) {
      setCategory(this);
      this.siteSettings.login_required = true;

      await render(template);

      const status = query(".activity-pub-status.not-active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.login_required_enabled"),
        "has the right title"
      );
      assert.strictEqual(
        status.innerText.trim(),
        I18n.t("discourse_activity_pub.status.label.not_active"),
        "has the right label"
      );
    });

    test("with plugin disabled", async function (assert) {
      setCategory(this);
      this.siteSettings.activity_pub_enabled = false;

      await render(template);

      const status = query(".activity-pub-status.not-active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.plugin_disabled"),
        "has the right title"
      );
      assert.strictEqual(
        status.innerText.trim(),
        I18n.t("discourse_activity_pub.status.label.not_active"),
        "has the right label"
      );
    });

    test("with activity pub disabled on category", async function (assert) {
      setCategory(this, { activity_pub_enabled: false });
      this.siteSettings.activity_pub_enabled = true;

      await render(template);

      const status = query(".activity-pub-status.not-active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.model_disabled", {
          model_type: "category",
        }),
        "has the right title"
      );
      assert.strictEqual(
        status.innerText.trim(),
        I18n.t("discourse_activity_pub.status.label.not_active"),
        "has the right label"
      );
    });

    test("with activity pub not ready on category", async function (assert) {
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: false,
      });
      this.siteSettings.activity_pub_enabled = true;

      await render(template);

      const status = query(".activity-pub-status.not-active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.model_not_ready", {
          model_type: "category",
        }),
        "has the right title"
      );
      assert.strictEqual(
        status.innerText.trim(),
        I18n.t("discourse_activity_pub.status.label.not_active"),
        "has the right label"
      );
    });

    test("with active activity pub", async function (assert) {
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: true,
      });
      this.siteSettings.activity_pub_enabled = true;

      await render(template);

      const status = query(".activity-pub-status.active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.model_active.first_post", {
          model_name: this.category.name,
        }),
        "has the right title"
      );
      assert.strictEqual(
        status.innerText.trim(),
        I18n.t("discourse_activity_pub.status.label.active"),
        "has the right label"
      );
    });

    test("updates correctly after messageBus message", async function (assert) {
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: true,
      });
      this.siteSettings.activity_pub_enabled = true;

      await render(template);
      await publishToMessageBus("/activity-pub", {
        model: {
          id: this.category.id,
          type: "category",
          ready: false,
          enabled: true,
        },
      });

      const status = query(".activity-pub-status.not-active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.model_not_ready", {
          model_type: "category",
        }),
        "has the right title"
      );
      assert.strictEqual(
        status.innerText.trim(),
        I18n.t("discourse_activity_pub.status.label.not_active"),
        "has the right label"
      );
    });
  }
);
