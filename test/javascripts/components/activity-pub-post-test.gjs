import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, skip } from "qunit";
import Post from "discourse/components/post";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DMenus from "float-kit/components/d-menus";

module("Discourse Activity Pub | Component | post", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(function () {
    this.siteSettings.post_menu_hidden_items = "";

    this.store = getOwner(this).lookup("service:store");
    const topic = this.store.createRecord("topic", { id: 123 });
    const post = this.store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
      created_at: new Date(new Date().getTime() - 30 * 60 * 1000),
      user_id: 1,
      username: "eviltrout",
    });

    this.post = post;
  });

  skip("non activity pub topic", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.currentUser.staff = true;
    this.post.activity_pub_enabled = false;
    this.set("changePostOwner", () => (this.owned = true));

    await render(
      <template>
        <Post @post={{self.post}} @changePostOwner={{self.changePostOwner}} />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");
    assert
      .dom("[data-content][data-identifier='admin-post-menu'] .change-owner")
      .exists("the change owner button is visible");
  });

  skip("activity pub topic", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.currentUser.staff = true;
    this.post.activity_pub_enabled = true;
    this.set("changePostOwner", () => (this.owned = true));

    await render(
      <template>
        <Post @post={{self.post}} @changePostOwner={{self.changePostOwner}} />
        <DMenus />
      </template>
    );

    await click(".post-menu-area .show-post-admin-menu");

    assert
      .dom("[data-content][data-identifier='admin-post-menu'] .change-owner")
      .doesNotExist("the change owner button is not visible");
  });
});
