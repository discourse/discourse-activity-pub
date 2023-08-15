import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";

module(
  "Discourse Activity Pub | Component | activity-pub-authorization",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<ActivityPubAuthorization @authorization={{this.authorization}} @remove={{this.removeAuthorization}} />`;

    test("displays the authorization component", async function (assert) {
      this.set("authorization", { actor_id: "https://external1.com/user/1" });
      this.set("removeAuthorization", () => {});

      await render(template);

      const link = query(
        "a.activity-pub-authorization-link[href='https://external1.com/user/1']"
      );
      assert.ok(exists(link));
      assert.strictEqual(
        link.textContent.trim(),
        "https://external1.com/user/1"
      );
      assert.ok(exists("#user_activity_pub_authorize_remove_authorization"));
    });
  }
);
