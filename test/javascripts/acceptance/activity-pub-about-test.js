import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import AboutFixtures from "../fixtures/about-fixtures";

acceptance("Discourse Activity Pub | About", function (needs) {
  needs.site({ activity_pub_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/ap/about.json", () =>
      helper.response(AboutFixtures["/ap/about.json"])
    );
  });

  test("lists the forum's actors", async function (assert) {
    await visit("/ap/about");

    assert
      .dom(".activity-pub-actors.categories .activity-pub-actor-card")
      .exists({ count: 2 });

    assert
      .dom(".activity-pub-actors.tags .activity-pub-actor-card")
      .exists({ count: 1 });

    assert
      .dom(
        ".activity-pub-actors.categories div.activity-pub-actor-card:first-of-type .follower-count"
      )
      .hasText("4 followers", "shows the right follower counts");
  });
});
