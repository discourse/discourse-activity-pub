import {
  acceptance,
  exists,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Site from "discourse/models/site";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import I18n from "I18n";

const createdAt = moment().subtract(2, "days");
const scheduledAt = moment().subtract(2, "days");
const publishedAt = moment().subtract(1, "days");
const deletedAt = moment();

const setupServer = (needs, _publishedAt = null) => {
  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    const firstPost = topicResponse.post_stream.posts[0];
    firstPost.cooked += '<div class="note">This is my note</div>';
    firstPost.created_at = createdAt;
    firstPost.activity_pub_enabled = true;
    firstPost.activity_pub_scheduled_at = scheduledAt;
    if (_publishedAt) {
      firstPost.activity_pub_published_at = _publishedAt;
    }
    server.get("/t/280.json", () => helper.response(topicResponse));
  });
};

acceptance(
  "Discourse Activity Pub | ActivityPub topic as user",
  function (needs) {
    needs.user({ moderator: false, admin: false });
    setupServer(needs, publishedAt);

    test("ActivityPub indicator element", async function (assert) {
      Site.current().set("activity_pub_enabled", true);

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "is not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | ActivityPub topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, publishedAt);

    test("When the plugin is disabled", async function (assert) {
      Site.current().set("activity_pub_enabled", false);

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "the activity pub indicator is not visible"
      );
    });

    test("ActivityPub indicator element", async function (assert) {
      Site.current().set("activity_pub_enabled", true);

      await visit("/t/280");

      assert.ok(
        exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "is visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Scheduled ActivityPub topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs);

    test("ActivityPub indicator element", async function (assert) {
      Site.current().set("activity_pub_enabled", true);

      await visit("/t/280");

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='Post was scheduled to be published via ActivityPub at ${scheduledAt.format(
            I18n.t("dates.long_no_year")
          )}']`
        ),
        "shows the right title"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, publishedAt);

    test("When the plugin is disabled", async function (assert) {
      Site.current().set("activity_pub_enabled", false);

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "the activity pub indicator is not visible"
      );
    });

    test("ActivityPub indicator element", async function (assert) {
      Site.current().set("activity_pub_enabled", true);

      await visit("/t/280");

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='Post was published via ActivityPub at ${publishedAt.format(
            I18n.t("dates.long_no_year")
          )}']`
        ),
        "shows the right title"
      );
    });

    test("ActivityPub status update", async function (assert) {
      Site.current().set("activity_pub_enabled", true);

      await visit("/t/280");

      const statusUpdate = {
        model: {
          id: 398,
          type: "post",
          published_at: publishedAt,
          deleted_at: deletedAt,
        },
      };
      await publishToMessageBus("/activity-pub", statusUpdate);

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='ActivityPub note was deleted at ${deletedAt.format(
            I18n.t("dates.long_no_year")
          )}']`
        ),
        "shows the right title"
      );
    });
  }
);
