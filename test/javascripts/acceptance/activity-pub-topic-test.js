import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import Site from "discourse/models/site";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

const createdAt = moment().subtract(2, "days");
const scheduledAt = moment().subtract(2, "days");
const publishedAt = moment().subtract(1, "days");
const deletedAt = moment();

const setupServer = (needs, attrs = {}) => {
  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    const firstPost = topicResponse.post_stream.posts[0];
    firstPost.cooked += '<div class="note">This is my note</div>';
    firstPost.created_at = createdAt;
    firstPost.activity_pub_enabled = true;
    firstPost.activity_pub_scheduled_at = scheduledAt;
    firstPost.activity_pub_object_type = "Note";
    firstPost.activity_pub_first_post = true;
    firstPost.activity_pub_is_first_post = true;
    Object.keys(attrs).forEach((attr) => {
      firstPost[attr] = attrs[attr];
    });
    server.get("/t/280.json", () => helper.response(topicResponse));
  });
};

acceptance(
  "Discourse Activity Pub | ActivityPub topic as user with post status not visible",
  function (needs) {
    needs.user({
      moderator: false,
      admin: false,
      groups: [AUTO_GROUPS.trust_level_0, AUTO_GROUPS.trust_level_1],
    });
    setupServer(needs, {
      activity_pub_published_at: publishedAt,
    });

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
  "Discourse Activity Pub | ActivityPub topic as user in a group with post status visible",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, {
      activity_pub_published_at: publishedAt,
      activity_pub_visibility: "public",
      activity_pub_domain: "external.com",
    });

    test("When the plugin is disabled", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "the activity pub indicator is not visible"
      );
    });

    test("ActivityPub indicator element", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.ok(
        exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "is visible"
      );
      assert.ok(
        exists(
          ".topic-post:nth-of-type(1) .post-info.activity-pub .d-icon-discourse-activity-pub"
        ),
        "displays the ActivityPub icon"
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
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='Note was scheduled to be published via ActivityPub from this site at ${scheduledAt.format(
            "h:mm a, MMM D"
          )}.']`
        ),
        "shows the right title"
      );
    });

    test("Post admin menu", async function (assert) {
      await visit("/t/280");
      await click(".show-more-actions");
      await click(".show-post-admin-menu");

      assert.ok(
        exists(".fk-d-menu .activity-pub-unschedule"),
        "The unschedule button was rendered"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Unscheduled ActivityPub topic as staff with First Post enabled",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, {
      activity_pub_scheduled_at: null,
      activity_pub_first_post: true,
    });

    test("Post admin menu", async function (assert) {
      await visit("/t/280");
      await click(".show-more-actions");
      await click(".show-post-admin-menu");

      assert.ok(
        exists(".fk-d-menu .activity-pub-schedule"),
        "The schedule button was rendered"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Unscheduled ActivityPub topic as staff with Full Topic enabled",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, {
      activity_pub_scheduled_at: null,
      activity_pub_first_post: false,
    });

    test("Post admin menu", async function (assert) {
      await visit("/t/280");
      await click(".show-more-actions");
      await click(".show-post-admin-menu");

      assert.ok(
        !exists(".fk-d-menu .activity-pub-schedule"),
        "The schedule button was not rendered"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub topic as staff with a local Note",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, {
      activity_pub_published_at: publishedAt,
      activity_pub_visibility: "public",
      activity_pub_local: true,
    });

    test("When the plugin is disabled", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "the activity pub indicator is not visible"
      );
    });

    test("ActivityPub indicator element", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='Note was published via ActivityPub from this site at ${publishedAt.format(
            "h:mm a, MMM D"
          )}.']`
        ),
        "shows the right title"
      );
    });

    test("ActivityPub state update", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      const stateUpdate = {
        model: {
          id: 398,
          type: "post",
          published_at: publishedAt,
          deleted_at: deletedAt,
        },
      };
      await publishToMessageBus("/activity-pub", stateUpdate);

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='Note was deleted via ActivityPub at ${deletedAt.format(
            "h:mm a, MMM D"
          )}.']`
        ),
        "shows the right title"
      );
    });

    test("ActivityPub post info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-post:nth-of-type(1) .post-info.activity-pub");
      assert.ok(exists(".activity-pub-post-info-modal"), "shows the modal");
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-state"
        ).innerText.trim(),
        `Note was published via ActivityPub from this site at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right state text"
      );
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-visibility"
        ).innerText.trim(),
        "Note is publicly addressed.",
        "shows the right visibility text"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub topic as staff with a remote Note",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, {
      activity_pub_published_at: publishedAt,
      activity_pub_visibility: "public",
      activity_pub_local: false,
      activity_pub_domain: "external.com",
      activity_pub_url: "https://external.com/note/1",
    });

    test("When the plugin is disabled", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "the activity pub indicator is not visible"
      );
    });

    test("ActivityPub indicator element", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.ok(
        exists(
          `.topic-post:nth-of-type(1) .post-info.activity-pub[title='Note was published via ActivityPub from external.com at ${publishedAt.format(
            "h:mm a, MMM D"
          )}.']`
        ),
        "shows the right title"
      );
    });

    test("ActivityPub post info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-post:nth-of-type(1) .post-info.activity-pub");
      assert.ok(exists(".activity-pub-post-info-modal"), "shows the modal");
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-state"
        ).innerText.trim(),
        `Note was published via ActivityPub from external.com at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right state text"
      );
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-visibility"
        ).innerText.trim(),
        "Note is publicly addressed.",
        "shows the right visibility text"
      );
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-url a"
        ).innerText.trim(),
        "Original Note on external.com.",
        "shows the right url text"
      );
      assert.strictEqual(
        query(".activity-pub-post-info-modal .activity-pub-url a").href,
        "https://external.com/note/1",
        "shows the right url href"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub topic as staff with a unpublished Note",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, {
      activity_pub_scheduled_at: null,
    });

    test("When the plugin is disabled", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.ok(
        !exists(".topic-post:nth-of-type(1) .post-info.activity-pub"),
        "the activity pub indicator is not visible"
      );
    });

    test("ActivityPub indicator element", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.ok(
        exists(
          ".topic-post:nth-of-type(1) .post-info.activity-pub[title='Note was not published via ActivityPub.']"
        ),
        "shows the right title"
      );
      assert.ok(
        exists(
          ".topic-post:nth-of-type(1) .post-info.activity-pub .d-icon-discourse-activity-pub-slash"
        ),
        "shows the right icon"
      );
    });

    test("ActivityPub post info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      await click(".topic-post:nth-of-type(1) .post-info.activity-pub");
      assert.ok(exists(".activity-pub-post-info-modal"), "shows the modal");
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-state"
        ).innerText.trim(),
        "Note was not published via ActivityPub.",
        "shows the right state text"
      );
    });
  }
);
