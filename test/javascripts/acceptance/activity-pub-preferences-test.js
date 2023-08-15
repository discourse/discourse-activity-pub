import {
  acceptance,
  exists,
  loggedInUser,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Discourse Activity Pub | Preferences", function (needs) {
  needs.user({
    activity_pub_authorizations: [
      { actor_id: "https://external1.com/user/1" },
      { actor_id: "https://external2.com/user/1" },
    ],
  });
  needs.site({ activity_pub_enabled: true });

  test("displays account authorization section", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);
    assert.ok(exists(".activity-pub-authorize-account"));
  });

  test("displays user's account authorizations", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);

    const first = query(
      `a.activity-pub-authorized-account[href='https://external1.com/user/1']`
    );
    const second = query(
      `a.activity-pub-authorized-account[href='https://external2.com/user/1']`
    );

    assert.strictEqual(
      first.textContent.trim(),
      "https://external1.com/user/1"
    );
    assert.strictEqual(
      second.textContent.trim(),
      "https://external2.com/user/1"
    );
  });
});
