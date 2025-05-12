import { getOwner } from "@ember/application";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
// import AppEvents from "discourse/services/app-events";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  currentUser,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import ActivityPubActorStatus from "discourse/plugins/discourse-activity-pub/discourse/components/activity-pub-actor-status";
import SiteActors from "../fixtures/site-actors-fixtures";

function setSite(context, attrs = {}) {
  context.siteSettings.activity_pub_enabled = attrs.activity_pub_enabled;
  context.siteSettings.login_required = !!attrs.activity_pub_publishing_enabled;
  Site.current().setProperties({
    activity_pub_enabled: attrs.activity_pub_enabled,
    activity_pub_publishing_enabled: attrs.activity_pub_publishing_enabled,
    activity_pub_actors: attrs.activity_pub_actors,
  });
}

function setCategory(context) {
  const categories = context.site.categoriesList;
  const category = categories.find((c) => c.id === 2);
  context.set("category", category);
}

function setTag(context) {
  const store = getOwner(context).lookup("service:store");
  const tag = store.createRecord("tag", { id: 1, name: "monkey" });
  context.set("tag", tag);
}

function setComposer(context, opts = {}) {
  opts.user ??= currentUser();
  // opts.appEvents = AppEvents.create();
  const store = getOwner(context).lookup("service:store");
  const composer = store.createRecord("composer", opts);
  context.set("composer", composer);
}

module(
  "Discourse Activity Pub | Component | activity-pub-actor-status with category",
  function (hooks) {
    setupRenderingTest(hooks);
    test("with publishing disabled", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: false,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setCategory(this);

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.category}}
            @modelType="category"
          />
        </template>
      );

      const status = query(".activity-pub-actor-status.publishing-disabled");
      assert.ok(status, "has the right class");
      assert
        .dom(status)
        .hasAttribute(
          "title",
          i18n("discourse_activity_pub.status.title.publishing_disabled"),
          "has the right title"
        );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.publishing_disabled"),
          "has the right label"
        );
    });

    test("with plugin disabled", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setCategory(this);

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.category}}
            @modelType="category"
          />
        </template>
      );

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert
        .dom(status)
        .hasAttribute(
          "title",
          i18n("discourse_activity_pub.status.title.plugin_disabled"),
          "has the right title"
        );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("with activity pub disabled on category", async function (assert) {
      const self = this;

      const categoryActors = cloneJSON(SiteActors.category);
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: {
          category: categoryActors.map((actor) => {
            if (actor.model_id === 2) {
              actor.enabled = false;
            }
            return actor;
          }),
        },
      });
      setCategory(this);

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.category}}
            @modelType="category"
          />
        </template>
      );

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_disabled", {
          model_type: "category",
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("with activity pub not ready on category", async function (assert) {
      const self = this;

      const categoryActors = cloneJSON(SiteActors.category);
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: {
          category: categoryActors.map((actor) => {
            if (actor.model_id === 2 && actor.model_type === "Category") {
              actor.enabled = true;
              actor.ready = false;
            }
            return actor;
          }),
        },
      });
      setCategory(this);

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.category}}
            @modelType="category"
          />
        </template>
      );

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_not_ready", {
          model_type: "category",
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("with active activity pub", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setCategory(this);

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.category}}
            @modelType="category"
          />
        </template>
      );

      const status = query(".activity-pub-actor-status.active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_active.first_post", {
          delay_minutes: this.siteSettings.activity_pub_delivery_delay_minutes,
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.active"),
          "has the right label"
        );
    });

    test("updates correctly after messageBus message", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setCategory(this);

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.category}}
            @modelType="category"
          />
        </template>
      );
      await publishToMessageBus("/activity-pub", {
        model: {
          id: this.category.id,
          type: "category",
          ready: false,
          enabled: true,
        },
      });

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_not_ready", {
          model_type: "category",
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("when in the composer", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setCategory(this);
      setComposer(this, {
        categoryId: this.category.id,
      });

      await render(
        <template>
          <ActivityPubActorStatus
            @model={{self.composer}}
            @modelType="composer"
          />
        </template>
      );

      const label = query(".activity-pub-actor-status .label");
      assert.strictEqual(
        label.innerText.trim(),
        i18n("discourse_activity_pub.visibility.label.public"),
        "has the right label text"
      );
    });
  }
);

module(
  "Discourse Activity Pub | Component | activity-pub-actor-status with tag",
  function (hooks) {
    setupRenderingTest(hooks);
    test("with publishing disabled", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: false,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setTag(this);

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );

      const status = query(".activity-pub-actor-status.publishing-disabled");
      assert.ok(status, "has the right class");
      assert
        .dom(status)
        .hasAttribute(
          "title",
          i18n("discourse_activity_pub.status.title.publishing_disabled"),
          "has the right title"
        );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.publishing_disabled"),
          "has the right label"
        );
    });

    test("with plugin disabled", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setTag(this);

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert
        .dom(status)
        .hasAttribute(
          "title",
          i18n("discourse_activity_pub.status.title.plugin_disabled"),
          "has the right title"
        );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("with activity pub disabled on tag", async function (assert) {
      const self = this;

      const tagActors = cloneJSON(SiteActors.tag);
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: {
          tag: tagActors.map((actor) => {
            if (actor.model_id === 1 && actor.model_type === "Tag") {
              actor.enabled = false;
            }
            return actor;
          }),
        },
      });
      setTag(this);

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_disabled", {
          model_type: "tag",
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("with activity pub not ready on tag", async function (assert) {
      const self = this;

      const tagActors = cloneJSON(SiteActors.tag);
      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: {
          tag: tagActors.map((actor) => {
            if (actor.model_id === 1 && actor.model_type === "Tag") {
              actor.enabled = true;
              actor.ready = false;
            }
            return actor;
          }),
        },
      });
      setTag(this);

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_not_ready", {
          model_type: "tag",
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("with active activity pub", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setTag(this);

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );

      const status = query(".activity-pub-actor-status.active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_active.first_post", {
          delay_minutes: this.siteSettings.activity_pub_delivery_delay_minutes,
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.active"),
          "has the right label"
        );
    });

    test("updates correctly after messageBus message", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setTag(this);

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );
      await publishToMessageBus("/activity-pub", {
        model: {
          id: this.tag.id,
          type: "tag",
          ready: false,
          enabled: true,
        },
      });

      const status = query(".activity-pub-actor-status.not-active");
      assert.ok(status, "has the right class");
      assert.dom(status).hasAttribute(
        "title",
        i18n("discourse_activity_pub.status.title.model_not_ready", {
          model_type: "tag",
        }),
        "has the right title"
      );
      assert
        .dom(status)
        .hasText(
          i18n("discourse_activity_pub.status.label.not_active"),
          "has the right label"
        );
    });

    test("when in the composer", async function (assert) {
      const self = this;

      setSite(this, {
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: cloneJSON(SiteActors),
      });
      setTag(this);
      setComposer(this, {
        tags: [this.tag.name],
      });

      await render(
        <template>
          <ActivityPubActorStatus @model={{self.tag}} @modelType="tag" />
        </template>
      );

      assert
        .dom(".activity-pub-actor-status .label")
        .hasText(
          i18n("discourse_activity_pub.visibility.label.public"),
          "has the right label text"
        );
    });
  }
);
