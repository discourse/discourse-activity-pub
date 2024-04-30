import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  exists,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import { default as Authorizations } from "../fixtures/authorization-fixtures";

acceptance("Discourse Activity Pub | Preferences", function (needs) {
  needs.user();
  needs.site({ activity_pub_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/ap/auth.json", () => helper.response(Authorizations["/ap/auth.json"]));
  });

  test("displays account authorization section", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);
    assert.ok(exists(".activity-pub-authorize"));
  });

  test("displays account authorizations", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);

    assert.ok(exists(".activity-pub-authorizations"));
  });
});
