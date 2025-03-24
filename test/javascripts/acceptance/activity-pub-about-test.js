import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { default as AboutFixtures } from "../fixtures/about-fixtures";

acceptance("Discourse Activity Pub | About", function (needs) {
  needs.site({ activity_pub_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/ap/about.json", () =>
      helper.response(AboutFixtures["/ap/about.json"])
    );
  });

  test("lists the forum's actors", async function (assert) {
    await visit("/ap/about");

    const categoryActors = queryAll(
      ".activity-pub-actors.categories .activity-pub-actor-card"
    );
    assert.strictEqual(categoryActors.length, 2);

    const tagActors = queryAll(
      ".activity-pub-actors.tags .activity-pub-actor-card"
    );
    assert.strictEqual(tagActors.length, 1);

    assert.strictEqual(
      query(
        ".activity-pub-actors.categories div.activity-pub-actor-card:first-of-type .follower-count"
      ).innerText.trim(),
      "4 followers",
      "shows the right follower counts"
    );
  });
});
