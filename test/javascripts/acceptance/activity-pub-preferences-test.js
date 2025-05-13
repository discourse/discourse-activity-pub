import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import Authorizations from "../fixtures/authorization-fixtures";

acceptance("Discourse Activity Pub | Preferences", function (needs) {
  needs.user();
  needs.site({ activity_pub_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/ap/auth.json", () =>
      helper.response(Authorizations["/ap/auth.json"])
    );
  });

  test("displays account authorization section", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);
    assert.dom(".activity-pub-authorize").exists();
  });

  test("displays account authorizations", async function (assert) {
    await visit(`/u/${loggedInUser().username}/preferences/activity-pub`);

    assert
      .dom(".activity-pub-authorizations .activity-pub-actor-table")
      .exists("the authorizations table is visible");
    assert
      .dom(".activity-pub-actor-table-row")
      .exists({ count: 2 }, "authorized actors are visible");
    assert
      .dom(".activity-pub-actor-image img")
      .hasAttribute(
        "src",
        /\/images\/avatar\.png/,
        "authorized actor image is visible"
      );
    assert
      .dom(".activity-pub-actor-name")
      .hasText("Angus", "authorized actor name is visible");
    assert
      .dom(".activity-pub-actor-handle")
      .hasText("@angus_ap@test.local", "authorized actor handle is visible");
  });
});
