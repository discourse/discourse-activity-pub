import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  currentUser,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import I18n from "I18n";
import Site from "discourse/models/site";
import AppEvents from "discourse/services/app-events";
import { getOwner } from "@ember/application";

function setSite(context, attrs = {}) {
  context.siteSettings.activity_pub_enabled = attrs.activity_pub_enabled;
  context.siteSettings.login_required = attrs.login_required;
  Site.current().set(
    "activity_pub_enabled",
    attrs.activity_pub_enabled && !attrs.login_required
  );
}

function setCategory(context, attrs = {}) {
  const categories = context.site.categoriesList;
  const category = categories.firstObject;

  Object.keys(attrs).forEach((key) => {
    category.set(key, attrs[key]);
  });

  context.set("category", category);
}

function setComposer(context, opts = {}) {
  opts.user ??= currentUser();
  opts.appEvents = AppEvents.create();
  const store = getOwner(context).lookup("service:store");
  const composer = store.createRecord("composer", opts);
  context.set("composer", composer);
}

module(
  "Discourse Activity Pub | Component | activity-pub-status",
  function (hooks) {
    setupRenderingTest(hooks);
    const template = hbs`<ActivityPubStatus @model={{this.category}} @modelType="category" />`;

    test("with login required enabled", async function (assert) {
      setSite(this, { activity_pub_enabled: true, login_required: true });
      setCategory(this);

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
      setSite(this, { activity_pub_enabled: false, login_required: false });
      setCategory(this);

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
      setSite(this, { activity_pub_enabled: true, login_required: false });
      setCategory(this, { activity_pub_enabled: false });

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
      setSite(this, { activity_pub_enabled: true, login_required: false });
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: false,
      });

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
      setSite(this, { activity_pub_enabled: true, login_required: false });
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: true,
      });

      await render(template);

      const status = query(".activity-pub-status.active");
      assert.ok(status, "has the right class");
      assert.strictEqual(
        status.title,
        I18n.t("discourse_activity_pub.status.title.model_active.first_post", {
          category_name: this.category.name,
          delay_minutes: this.siteSettings.activity_pub_delivery_delay_minutes,
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
      setSite(this, { activity_pub_enabled: true, login_required: false });
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: true,
      });

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

    test("when in the composer", async function (assert) {
      const composerTemplate = hbs`<ActivityPubStatus @model={{this.composer}} @modelType="composer" />`;

      setSite(this, { activity_pub_enabled: true });
      setCategory(this, {
        activity_pub_enabled: true,
        activity_pub_ready: true,
        activity_pub_default_visibility: "public",
      });
      setComposer(this, {
        categoryId: this.category.id,
      });

      await render(composerTemplate);

      const label = query(".activity-pub-status .label");
      assert.strictEqual(
        label.innerText.trim(),
        I18n.t("discourse_activity_pub.visibility.label.public"),
        "has the right label text"
      );
    });
  }
);
