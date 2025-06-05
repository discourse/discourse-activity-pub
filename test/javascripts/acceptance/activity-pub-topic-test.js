import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import SiteActors from "../fixtures/site-actors-fixtures";

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
    topicResponse.activity_pub_post_actors = postAttrs.map((attrs, i) => {
      let post = topicResponse.post_stream.posts[i];
      return {
        post_id: post.id,
        actor: {
          handle: `actor${i}@domain.com`,
        },
      };
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

      assert
        .dom(".topic-map__activity-pub")
        .doesNotExist("the topic map is not visible");
      assert
        .dom(".topic-post:nth-of-type(2) .post-info.activity-pub")
        .doesNotExist("the post status is not visible");
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

      assert
        .dom(".topic-map__activity-pub")
        .doesNotExist("the activity pub topic map is not visible");
    });

    test("When the plugin is enabled", async function (assert) {
      this.siteSettings.activity_pub_post_status_visibility_groups = "2";
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.dom(".topic-map__activity-pub").exists("the topic map is visible");
      assert
        .dom(".topic-post:nth-of-type(3) .post-info.activity-pub")
        .exists("is visible");
    });

    test("post status update", async function (assert) {
      this.siteSettings.activity_pub_post_status_visibility_groups = "2";
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      const postStatusUpdate = {
        model: {
          id: 419,
          type: "post",
          topic_id: 280,
          published_at: publishedAt,
          deleted_at: deletedAt,
        },
      };
      await publishToMessageBus("/activity-pub", postStatusUpdate);

      assert
        .dom(
          `.topic-post:nth-of-type(3) .activity-pub-post-status[title='Post was deleted via ActivityPub on ${deletedAt.format(
            i18n("dates.time_short_day")
          )}.']`
        )
        .exists("shows the right post status text");
    });
  }
);

acceptance(
  "Discourse Activity Pub | ActivityPub topic as anon user when post status is visible to everyone",
  function (needs) {
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
      this.siteSettings.activity_pub_post_status_visibility_groups = "0";
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert
        .dom(".topic-map__activity-pub")
        .doesNotExist("the activity pub topic map is not visible");
    });

    test("When the plugin is enabled", async function (assert) {
      this.siteSettings.activity_pub_post_status_visibility_groups = "0";
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert.dom(".topic-map__activity-pub").exists("the topic map is visible");
      assert
        .dom(".topic-post:nth-of-type(3) .post-info.activity-pub")
        .exists("is visible");
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

      assert
        .dom(".topic-map__activity-pub .activity-pub-topic-status")
        .hasText(
          `Topic is scheduled to be published via ActivityPub on ${scheduledAt.format(
            i18n("dates.time_short_day")
          )}.`,
          "shows the right status text"
        );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub full_topic topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(
      needs,
      [
        {
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: true,
          activity_pub_full_topic: true,
        },
        {
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: true,
          activity_pub_full_topic: true,
        },
        {},
      ],
      {
        activity_pub_published_at: publishedAt,
        activity_pub_object_type: "Collection",
        activity_pub_object_id: "https://local.com/collection/1234567",
        activity_pub_full_topic: true,
      }
    );

    test("When the plugin is disabled", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: false,
        activity_pub_publishing_enabled: false,
      });

      await visit("/t/280");

      assert
        .dom(".topic-map__activity-pub")
        .doesNotExist("the topic map is not visible");
    });

    test("topic map", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      assert
        .dom(".topic-map__activity-pub .activity-pub-topic-status")
        .hasText(
          `Topic was published via ActivityPub on ${publishedAt.format(
            i18n("dates.time_short_day")
          )}.`,
          "shows the right status text"
        );
    });

    test("topic status update", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      const topicStatusUpdate = {
        model: {
          id: 280,
          type: "topic",
          activity_pub_published_at: publishedAt,
          activity_pub_deleted_at: deletedAt,
        },
      };
      await publishToMessageBus("/activity-pub", topicStatusUpdate);

      assert
        .dom(".topic-map__activity-pub .activity-pub-topic-status")
        .hasText(
          `Topic was deleted via ActivityPub on ${deletedAt.format(
            i18n("dates.time_short_day")
          )}.`,
          "shows the right status text"
        );
    });

    test("topic modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-map__activity-pub .activity-pub-topic-status");
      assert.dom(".activity-pub-topic-info-modal").exists("shows the modal");

      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-topic-status")
        .hasText(
          `Topic was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right topic status text"
        );
      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-post-status")
        .hasText(
          `Post was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right post status text"
        );
      assert
        .dom(
          ".activity-pub-topic-info-modal .activity-pub-attribute.object-type.collection"
        )
        .exists("shows the right topic object type attribute");
      assert
        .dom(
          ".activity-pub-topic-info-modal .activity-pub-attribute.object-type.note"
        )
        .exists("shows the right post object type attribute");

      const topicStatusUpdate = {
        model: {
          id: 280,
          type: "topic",
          activity_pub_published_at: publishedAt,
          activity_pub_deleted_at: deletedAt,
        },
      };
      await publishToMessageBus("/activity-pub", topicStatusUpdate);

      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-topic-status")
        .hasText(
          `Topic was deleted on ${deletedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "handles a status update"
        );

      assert
        .dom(".activity-pub-topic-actions .action.publish-all")
        .exists("shows the publish all posts action");
      assert
        .dom(
          ".activity-pub-topic-actions .action.publish-all .action-description"
        )
        .hasText(
          `Publish 18 unpublished posts in Topic #280. Posts will not be delivered to the followers of the Group Actors.`,
          "shows the right publish all description"
        );
      assert
        .dom(".activity-pub-post-actions .action.deliver")
        .exists("shows the post deliver action");

      const topicActionStatusUpdate = {
        model: {
          id: 280,
          type: "topic",
          activity_pub_published_post_count: 20,
          activity_pub_total_post_count: 20,
        },
      };
      await publishToMessageBus("/activity-pub", topicActionStatusUpdate);
      assert
        .dom(
          ".activity-pub-topic-actions .action.publish-all .action-description"
        )
        .hasText(
          `Publish all posts is disabled. All posts in Topic #280 are already published.`,
          "handles topic action status updates"
        );
    });

    test("post modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
        activity_pub_actors: SiteActors,
      });

      await visit("/t/280");

      await click(".topic-post:nth-of-type(4) .activity-pub-post-status");
      assert.dom(".activity-pub-post-info-modal").exists("shows the modal");

      assert
        .dom(".activity-pub-post-info-modal .activity-pub-post-status")
        .hasText("Post is not published.", "shows the right status text");
      assert
        .dom(".activity-pub-post-actions .action.publish")
        .exists("shows the publish post action");
      assert
        .dom(".activity-pub-post-actions .action.publish .action-description")
        .hasText(
          `Publish Post #3 without delivering it. The Group Actors have no followers to deliver to.`,
          "shows the right publish description"
        );
      const topicStatusUpdate = {
        model: {
          id: 280,
          type: "topic",
          activity_pub_published_at: null,
        },
      };
      await publishToMessageBus("/activity-pub", topicStatusUpdate);
      assert
        .dom(".activity-pub-post-actions .action.publish .action-description")
        .hasText(
          "Publish is disabled for Post #3. Topic #280 is not published.",
          "handles topic status updates"
        );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Published ActivityPub first_post topic as staff",
  function (needs) {
    needs.user({ moderator: true, admin: false });
    setupServer(
      needs,
      [
        {
          activity_pub_first_post: true,
          activity_pub_published_at: publishedAt,
          activity_pub_visibility: "public",
          activity_pub_local: true,
        },
      ],
      {
        activity_pub_published_at: publishedAt,
        activity_pub_full_topic: false,
      }
    );

    test("ActivityPub topic info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-map__activity-pub .activity-pub-topic-status");
      assert.dom(".activity-pub-topic-info-modal").exists("shows the modal");

      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-topic-status")
        .hasText(
          `Topic was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right topic status text"
        );
      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-post-status")
        .hasText(
          `Post was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right post status text"
        );
      assert
        .dom(
          ".activity-pub-topic-info-modal .activity-pub-attribute.object-type.collection"
        )
        .doesNotExist("does not show a topic object type attribute");
      assert
        .dom(
          ".activity-pub-topic-info-modal .activity-pub-attribute.object-type.note"
        )
        .exists("shows the right post object type attribute");
      assert
        .dom(".activity-pub-topic-actions .action.publish-all")
        .doesNotExist("does not show the publish all posts action");
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

      assert
        .dom(".activity-pub-topic-status")
        .hasText(
          `Topic was published via ActivityPub by @cat_1@test.local on ${publishedAt.format(
            i18n("dates.time_short_day")
          )}.`,
          "shows the right topic status text"
        );
      assert
        .dom(
          `.topic-post:nth-of-type(3) .activity-pub-post-status[title='Post was published via ActivityPub by actor1@domain.com on ${publishedAt.format(
            i18n("dates.time_short_day")
          )}.']`
        )
        .exists("shows the right post status text");
    });

    test("ActivityPub topic info modal", async function (assert) {
      Site.current().setProperties({
        activity_pub_enabled: true,
        activity_pub_publishing_enabled: true,
      });

      await visit("/t/280");

      await click(".topic-map__activity-pub .activity-pub-topic-status");
      assert.dom(".activity-pub-topic-info-modal").exists("shows the modal");

      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-topic-status")
        .hasText(
          `Topic was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right topic status text"
        );
      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-post-status")
        .hasText(
          `Post was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right post status text"
        );
      assert
        .dom(".activity-pub-topic-info-modal .activity-pub-post-status")
        .hasText(
          `Post was published on ${publishedAt.format(
            i18n("dates.long_with_year")
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
      assert.dom(".activity-pub-post-info-modal").exists("shows the modal");
      assert
        .dom(".activity-pub-post-info-modal .activity-pub-post-status")
        .hasText(
          `Post was published on ${publishedAt.format(
            i18n("dates.long_with_year")
          )}.`,
          "shows the right status text"
        );
      assert
        .dom(".activity-pub-post-info-modal .activity-pub-attribute.visibility")
        .hasText("Public", "shows the right visibility text");
    });
  }
);
