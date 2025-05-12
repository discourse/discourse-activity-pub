import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, skip } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Discourse Activity Pub | Component | Widget | post", function (hooks) {
  setupRenderingTest(hooks);

  skip("non activity pub topic", async function (assert) {
    this.currentUser.admin = true;
    this.set("args", { canManage: true, activity_pub_enabled: false });
    this.set("changePostOwner", () => (this.owned = true));

    await render(hbs`
        <MountWidget @widget="post" @args={{this.args}} @changePostOwner={{this.changePostOwner}} />
      `);

    await click(".post-menu-area .show-post-admin-menu");
    assert
      .dom(".post-admin-menu button.change-owner")
      .exists("the change owner button is visible");
  });

  skip("activity pub topic", async function (assert) {
    this.currentUser.admin = true;
    this.set("args", { canManage: true, activity_pub_enabled: true });
    this.set("changePostOwner", () => (this.owned = true));

    await render(hbs`
        <MountWidget @widget="post" @args={{this.args}} @changePostOwner={{this.changePostOwner}} />
      `);

    await click(".post-menu-area .show-post-admin-menu");
    assert
      .dom(".post-admin-menu button.change-owner")
      .doesNotExist("the change owner button is not visible");
  });
});
