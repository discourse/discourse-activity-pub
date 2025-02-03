import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { default as SiteActors } from "../fixtures/site-actors-fixtures";

const createdAt = moment().subtract(2, "days");
const scheduledAt = moment().add(3, "minutes");
const publishedAt = moment().subtract(1, "days");
const deletedAt = moment();

const setupServer = (needs, postAttrs = [], topicAttrs = {}) => {
  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    postAttrs.forEach((attrs, i) => {
      let post = topicResponse.post_stream.posts[i];
      post.cooked += `<div class="note">This is my note ${i}</div>`;
      post.created_at = createdAt;
      post.activity_pub_enabled = true;
      post.activity_pub_object_type = "Note";
      post.activity_pub_first_post = true;
      if (i === 0) {
        post.activity_pub_is_first_post = true;
      }
      Object.keys(attrs).forEach((attr) => {
        post[attr] = attrs[attr];
      });
    });
    topicResponse.activity_pub_total_post_count = 20;
    topicResponse.activity_pub_published_post_count =
      topicResponse.post_stream.posts.filter(
        (p) => !!p.activity_pub_published_at
      ).length;
    topicResponse.activity_pub_enabled = true;
    topicResponse.activity_pub_local = true;
    topicResponse.activity_pub_actor = SiteActors.category[0];
    Object.keys(topicAttrs).forEach((topicAttr) => {
      topicResponse[topicAttr] = topicAttrs[topicAttr];
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
    setupServer(needs, [
      {
        activity_pub_published_at: publishedAt,
        activity_pub_local: true,
      },
      {
        activity_pub_published_at: publishedAt,
        activity_pub_local: true,
      },
    ]);

    test("ActivityPub topic and post elements", async function (assert) {
      this.siteSettings.activity_pub_post_status_visibility_groups = "1";
      Site.current().set("activity_pub_enabled", true);

      await visit("/t/280");

      assert.notOk(
        exists(".topic-map__activity-pub"),
        "the topic map is not visible"
      );
      assert.notOk(
        exists(".topic-post:nth-of-type(2) .post-info.activity-pub"),
        "the post status is not visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | ActivityPub topic as user in a group with post status visible",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(needs, [
      {
        activity_pub_published_at: publishedAt,
        activity_pub_visibility: "public",
        activity_pub_domain: "external.com",
        activity_pub_local: false,
      },
      {
        activity_pub_published_at: publishedAt,
        activity_pub_visibility: "public",
        activity_pub_local: true,
      },
    ]);

    test("When the plugin is disabled", async function (assert) {
      this.siteSettings.activity_pub_post_status_visibility_groups = "2";
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.notOk(
        exists(".topic-map__activity-pub"),
        "the activity pub topic map is not visible"
      );
    });

    test("When the plugin is enabled", async function (assert) {
      this.siteSettings.activity_pub_post_status_visibility_groups = "2";
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.ok(exists(".topic-map__activity-pub"), "the topic map is visible");
      assert.ok(
        exists(".topic-post:nth-of-type(3) .post-info.activity-pub"),
        "is visible"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Scheduled ActivityPub topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(
      needs,
      [
        {
          activity_pub_scheduled_at: scheduledAt,
          activity_pub_visibility: "public",
        },
      ],
      {
        activity_pub_scheduled_at: scheduledAt,
      }
    );

    test("topic map", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.strictEqual(
        query(
          ".topic-map__activity-pub .activity-pub-topic-status"
        ).innerText.trim(),
        `Topic is scheduled to be published via ActivityPub at ${scheduledAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right status text"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(
      needs,
      [
        {
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: true,
        },
        {
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: true,
        },
      ],
      {
        activity_pub_published_at: publishedAt,
      }
    );

    test("When the plugin is disabled", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert.notOk(
        exists(".topic-map__activity-pub"),
        "the topic map is not visible"
      );
    });

    test("topic map", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.strictEqual(
        query(
          ".topic-map__activity-pub .activity-pub-topic-status"
        ).innerText.trim(),
        `Topic was published via ActivityPub at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right status text"
      );
    });

    test("ActivityPub status update", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      const stateUpdate = {
        model: {
          id: 280,
          type: "topic",
          published_at: publishedAt,
          deleted_at: deletedAt,
        },
      };
      await publishToMessageBus("/activity-pub", stateUpdate);

      assert.strictEqual(
        query(
          ".topic-map__activity-pub .activity-pub-topic-status"
        ).innerText.trim(),
        `Topic was deleted via ActivityPub at ${deletedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right status text"
      );
    });

    test("ActivityPub topic info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-map__activity-pub .activity-pub-topic-status");
      assert.ok(exists(".activity-pub-topic-info-modal"), "shows the modal");

      assert.strictEqual(
        query(
          ".activity-pub-topic-info-modal .activity-pub-topic-status"
        ).innerText.trim(),
        `Collection was published at ${publishedAt.format("h:mm a, MMM D")}.`,
        "shows the right topic status text"
      );
      assert.strictEqual(
        query(
          ".activity-pub-topic-info-modal .activity-pub-post-status"
        ).innerText.trim(),
        `Note was published at ${publishedAt.format("h:mm a, MMM D")}.`,
        "shows the right post status text"
      );
    });

    test("ActivityPub topic admin modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: SiteActors,
      });

      await visit("/t/280");
      await click(".topic-admin-menu-trigger");
      await click(".show-activity-pub-topic-admin");

      assert.ok(exists(".activity-pub-topic-admin-modal"), "shows the modal");
      assert.ok(
        query(
          ".activity-pub-topic-admin-modal .activity-pub-topic-actions .action.publish-all"
        ),
        "shows the publish all posts action"
      );
      assert.strictEqual(
        query(
          ".activity-pub-topic-admin-modal .activity-pub-topic-actions .action.publish-all .action-description"
        ).innerText.trim(),
        `Publish 18 unpublished posts in Topic #280. Posts will not be delivered to the followers of the actors.`,
        "shows the right publish all description"
      );
      assert.ok(
        query(
          ".activity-pub-topic-admin-modal .activity-pub-post-actions .action.deliver"
        ),
        "shows the post deliver action"
      );
    });

    test("ActivityPub post info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-post:nth-of-type(3) .activity-pub-post-status");
      assert.ok(exists(".activity-pub-post-info-modal"), "shows the modal");

      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-post-status"
        ).innerText.trim(),
        `Note was published at ${publishedAt.format("h:mm a, MMM D")}.`,
        "shows the right status text"
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
    setupServer(
      needs,
      [
        {
          post_number: 1,
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: false,
          activity_pub_domain: "external.com",
          activity_pub_url: "https://external.com/note/1",
        },
        {
          post_number: 2,
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: false,
          activity_pub_domain: "external.com",
          activity_pub_url: "https://external.com/note/3",
        },
      ],
      {
        activity_pub_published_at: publishedAt,
        activity_pub_local: false,
      }
    );

    test("ActivityPub topic and post status", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.strictEqual(
        query(".activity-pub-topic-status").innerText.trim(),
        `Topic was published via ActivityPub by @cat_1@test.local at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right topic status text"
      );
      assert.ok(
        exists(
          `.topic-post:nth-of-type(3) .activity-pub-post-status[title='Post was published via ActivityPub on external.com at ${publishedAt.format(
            "h:mm a, MMM D"
          )}.']`
        ),
        "shows the right post status text"
      );
    });

    test("ActivityPub topic info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-map__activity-pub .activity-pub-topic-status");
      assert.ok(exists(".activity-pub-topic-info-modal"), "shows the modal");

      assert.strictEqual(
        query(
          ".activity-pub-topic-info-modal .activity-pub-topic-status"
        ).innerText.trim(),
        `Collection was published by @cat_1@test.local at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right topic status text"
      );
      assert.strictEqual(
        query(
          ".activity-pub-topic-info-modal .activity-pub-post-status"
        ).innerText.trim(),
        `Note was published on external.com at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right post status text"
      );
    });

    test("ActivityPub post info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-post:nth-of-type(3) .activity-pub-post-status");
      assert.ok(exists(".activity-pub-post-info-modal"), "shows the modal");
      assert.strictEqual(
        query(
          ".activity-pub-post-info-modal .activity-pub-post-status"
        ).innerText.trim(),
        `Note was published on external.com at ${publishedAt.format(
          "h:mm a, MMM D"
        )}.`,
        "shows the right status text"
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
        "https://external.com/note/3",
        "shows the right url href"
      );
    });
  }
);
