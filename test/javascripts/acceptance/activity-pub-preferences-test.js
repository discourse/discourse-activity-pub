import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  exists,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";

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
    assert.ok(exists(".activity-pub-authorize"));
  });

  test("displays account authorizations", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);

    assert.ok(exists(".activity-pub-authorizations"));
    assert.ok(
      exists(
        "a.activity-pub-authorization-link[href='https://external1.com/user/1']"
      )
    );
    assert.ok(
      exists(
        "a.activity-pub-authorization-link[href='https://external2.com/user/1']"
      )
    );
  });
});
