import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { default as AboutFixtures } from "../fixtures/about-fixtures";

acceptance("Discourse Activity Pub | About", function (needs) {
  needs.site({ activity_pub_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/ap/local/about.json", () =>
      helper.response(AboutFixtures["/ap/local/about.json"])
    );
  });

  test("lists the forum's actors", async function (assert) {
    await visit("/ap/local/about");

    const actors = queryAll(".activity-pub-actors-list .activity-pub-actor");
    assert.strictEqual(actors.length, 3);
  });
});
