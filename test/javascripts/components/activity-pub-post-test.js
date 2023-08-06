import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";

module("Discourse Activity Pub | Component | Widget | post", function (hooks) {
  setupRenderingTest(hooks);

  test("non activity pub topic", async function (assert) {
    this.currentUser.admin = true;
    this.set("args", { canManage: true, activity_pub_enabled: false });
    this.set("changePostOwner", () => (this.owned = true));

    await render(hbs`
        <MountWidget @widget="post" @args={{this.args}} @changePostOwner={{this.changePostOwner}} />
      `);

    await click(".post-menu-area .show-post-admin-menu");
    assert.ok(
      exists(".post-admin-menu button.change-owner"),
      "the change owner button is visible"
    );
  });

  test("activity pub topic", async function (assert) {
    this.currentUser.admin = true;
    this.set("args", { canManage: true, activity_pub_enabled: true });
    this.set("changePostOwner", () => (this.owned = true));

    await render(hbs`
        <MountWidget @widget="post" @args={{this.args}} @changePostOwner={{this.changePostOwner}} />
      `);

    await click(".post-menu-area .show-post-admin-menu");
    assert.ok(
      !exists(".post-admin-menu button.change-owner"),
      "the change owner button is not visible"
    );
  });
});
