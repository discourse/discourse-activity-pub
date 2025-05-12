import { click, currentURL, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import Actors from "../fixtures/actors-fixtures";
import Followers from "../fixtures/followers-fixtures";
import Follows from "../fixtures/follows-fixtures";
import SiteActors from "../fixtures/site-actors-fixtures";

const actorPath = `/ap/local/actor/2`;
const followsPath = `${actorPath}/follows`;
const followersPath = `${actorPath}/followers`;

acceptance(
  "Discourse Activity Pub | Discovery without site enabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: false,
      activity_pub_publishing_enabled: false,
      activity_pub_actors: SiteActors,
    });

    test("with a non-category route", async function (assert) {
      await visit("/latest");

      assert
        .dom(".activity-pub-discovery")
        .doesNotExist("the discovery button is not visible");
    });

    test("with a category route without category enabled", async function (assert) {
      const category = Category.findById(2);

      await visit(category.url);

      assert
        .dom(".activity-pub-category-nav.visible")
        .doesNotExist("the ActivityPub nav button is not visible");
    });

    test("with a category route with category enabled", async function (assert) {
      const category = Category.findById(2);
      category.set("activity_pub_enabled", true);

      await visit(category.url);

      assert
        .dom(".activity-pub-category-nav.visible")
        .doesNotExist("the ActivityPub nav button is not visible");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery with site enabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followersPath}.json`, () =>
        helper.response(Followers[followersPath])
      );
      server.get("/tag/:tag_name/notifications", (request) => {
        return helper.response({
          tag_notification: {
            id: request.params.tag_name,
            notification_level: 1,
          },
        });
      });
      server.get("/tag/:tag_name/l/latest.json", (request) => {
        return helper.response({
          users: [],
          primary_groups: [],
          topic_list: {
            can_create_topic: true,
            draft: null,
            draft_key: "new_topic",
            draft_sequence: 1,
            per_page: 30,
            tags: [
              {
                id: 1,
                name: request.params.tag_name,
                topic_count: 1,
              },
            ],
            topics: [],
          },
        });
      });
    });

    test("with a non-category route", async function (assert) {
      Site.current().set("activity_pub_actors", SiteActors);

      await visit("/latest");

      assert
        .dom(".activity-pub-category-nav.visible")
        .doesNotExist("the ActivityPub nav button is not visible");
    });

    test("with a category without an activity pub actor", async function (assert) {
      const category = Category.findById(2);

      Site.current().set("activity_pub_actors", []);

      await visit(category.url);

      assert
        .dom(".activity-pub-category-nav.visible")
        .doesNotExist("the ActivityPub nav button is not visible");
    });

    test("with a category with an activity pub actor", async function (assert) {
      const category = Category.findById(2);

      Site.current().set("activity_pub_actors", SiteActors);

      await visit(category.url);

      assert
        .dom(".activity-pub-route-nav.visible")
        .exists("the ActivityPub nav button is visible");

      await click(".activity-pub-route-nav");

      assert
        .dom(".activity-pub-banner")
        .exists("the ActivityPub category banner is visible");
      assert.dom(".activity-pub-banner-text .desktop").hasText(
        i18n("discourse_activity_pub.banner.text", {
          model_name: "Cat 2",
        }),
        "shows the right banner text"
      );

      await triggerEvent(".fk-d-tooltip__trigger", "pointermove");
      assert
        .dom(".fk-d-tooltip__inner-content")
        .hasText(
          i18n("discourse_activity_pub.banner.public_first_post"),
          "shows the right category banner tip"
        );
    });

    test("when routing from a category with an actor to one without", async function (assert) {
      const category = Category.findById(2);
      Site.current().set("activity_pub_actors", SiteActors);

      await visit(category.url);

      assert
        .dom(".activity-pub-route-nav.visible")
        .exists("the ActivityPub nav button is visible");

      const categoryDrop = selectKit(".category-drop");
      await categoryDrop.expand();
      await categoryDrop.selectRowByValue(7);

      assert
        .dom(".activity-pub-route-nav.visible")
        .doesNotExist("the ActivityPub nav button is not visible");
    });

    test("when routing from a tag with an actor to one without", async function (assert) {
      Site.current().setProperties({
        activity_pub_actors: SiteActors,
        top_tags: ["monkey", "dog"],
      });

      await visit("/tag/monkey");

      assert
        .dom(".activity-pub-route-nav.visible")
        .exists("the ActivityPub nav button is visible");

      const tagDrop = selectKit(".tag-drop");
      await tagDrop.expand();
      await tagDrop.selectRowByName("dog");

      assert
        .dom(".activity-pub-route-nav.visible")
        .doesNotExist("the ActivityPub nav button is not visible");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery with publishing disabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: false,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followsPath}.json`, () => helper.response({ follows: [] }));
    });

    test("with a category route with activity pub ready", async function (assert) {
      const category = Category.findById(2);

      await visit(category.url);
      await click(".activity-pub-route-nav");

      assert
        .dom(".activity-pub-banner")
        .doesNotExist("the ActivityPub banner is not visible");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery ActivityPub followers route with publishing disabled",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: false,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get("/ap/local/actor/1", () =>
        helper.response(Actors["/ap/local/actor/1"])
      );
    });

    test("returns 404", async function (assert) {
      await visit("/ap/local/actor/1/followers");
      assert.strictEqual(currentURL(), "/404");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery ActivityPub followers route without followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followersPath}.json`, () =>
        helper.response({ followers: [] })
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit(followersPath);

      assert
        .dom(".activity-pub-follow-table.followers")
        .doesNotExist("the ActivityPub followers table is not visible");
      assert
        .dom(".activity-pub-followers-container")
        .hasText(i18n("search.no_results"), "no results shown");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery ActivityPub followers route with followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followersPath}.json`, () =>
        helper.response(Followers[followersPath])
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit(followersPath);

      assert
        .dom(".activity-pub-follow-table.followers")
        .exists("the ActivityPub followers table is visible");
      assert.strictEqual(
        document.querySelectorAll(".activity-pub-follow-table-row").length,
        2,
        "followers are visible"
      );
      assert
        .dom(".activity-pub-actor-image img")
        .hasAttribute(
          "src",
          /\/images\/avatar\.png/,
          "follower image is visible"
        );
      assert
        .dom(".activity-pub-actor-name")
        .hasText("Angus", "follower name is visible");
      assert
        .dom(".activity-pub-actor-handle")
        .hasText("@angus_ap@test.local", "follower handle is visible");
      assert
        .dom(".activity-pub-follow-table-user a.avatar")
        .hasAttribute("href", /\/u\/angus/, "follower user avatar is visible");
      assert
        .dom(".activity-pub-follow-table-followed-at")
        .hasText("Feb 8, 2013", "follower followed at is visible");
      assert
        .dom(".activity-pub-follow-btn")
        .exists("the ActivityPub follow btn is visible");
      await click(".activity-pub-follow-btn");
      assert
        .dom(".modal.activity-pub-follow-modal")
        .exists("shows the ActivityPub follow modal");
      assert.dom("#discourse-modal-title").hasText(
        i18n("discourse_activity_pub.follow.title", {
          actor: "Cat 2",
        }),
        "ActivityPub modal has the right title"
      );
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery ActivityPub follows route with no admin actor permission",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get("/ap/local/actor/1", () =>
        helper.response(Actors["/ap/local/actor/1"])
      );
      server.get("/ap/local/actor/1/follows.json", () =>
        helper.response(Follows["/ap/local/actor/1/follows"])
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit("/ap/local/actor/1/follows");

      assert
        .dom(".activity-pub-follow-table.follows")
        .exists("the ActivityPub follows table is visible");
      assert.strictEqual(
        document.querySelectorAll(".activity-pub-follow-table-row").length,
        2,
        "follows are visible"
      );
      assert
        .dom(".activity-pub-actor-image img")
        .hasAttribute(
          "src",
          /\/images\/avatar\.png/,
          "follower image is visible"
        );
      assert
        .dom(".activity-pub-actor-name")
        .hasText("Angus", "follower name is visible");
      assert
        .dom(".activity-pub-actor-handle")
        .hasText("@angus_ap@test.local", "follow handle is visible");
      assert
        .dom(".activity-pub-follow-table-user a.avatar")
        .hasAttribute("href", /\/u\/angus/, "follow user avatar is visible");
      assert
        .dom(".activity-pub-follow-table-followed-at")
        .hasText("Feb 8, 2013", "follower followed at is visible");
      assert
        .dom(".activity-pub-actor-follow-btn")
        .doesNotExist("the ActivityPub actor follow btn is not visible");
      assert
        .dom(".activity-pub-actor-unfollow-btn")
        .doesNotExist("the ActivityPub actor unfollow btn is not visible");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery ActivityPub subcategory follows route with admin actor permission",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get("/ap/local/actor/3", () =>
        helper.response(Actors["/ap/local/actor/3"])
      );
      server.get(`/ap/local/actor/3/follows.json`, () =>
        helper.response({ follows: [] })
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit("/ap/local/actor/3/follows");

      assert
        .dom(".activity-pub-follows-container")
        .exists("the ActivityPub follows route is visible");
    });
  }
);

acceptance(
  "Discourse Activity Pub | Discovery ActivityPub category follows route with admin actor permission with followers",
  function (needs) {
    needs.user();
    needs.site({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: SiteActors,
    });
    needs.pretender((server, helper) => {
      server.get(actorPath, () => helper.response(Actors[actorPath]));
      server.get(`${followsPath}.json`, () =>
        helper.response(Follows[followsPath])
      );
    });

    test("with activity pub ready", async function (assert) {
      await visit(followsPath);

      assert
        .dom(".activity-pub-follow-table.follows")
        .exists("the ActivityPub follows table is visible");
      assert.strictEqual(
        document.querySelectorAll(".activity-pub-follow-table-row").length,
        2,
        "follows are visible"
      );
      assert
        .dom(".activity-pub-actor-image img")
        .hasAttribute(
          "src",
          /\/images\/avatar\.png/,
          "follower image is visible"
        );
      assert
        .dom(".activity-pub-actor-name")
        .hasText("Angus", "follower name is visible");
      assert
        .dom(".activity-pub-actor-handle")
        .hasText("@angus_ap@test.local", "follow handle is visible");
      assert
        .dom(".activity-pub-follow-table-user a.avatar")
        .hasAttribute("href", /\/u\/angus/, "follow user avatar is visible");
      assert
        .dom(".activity-pub-follow-table-followed-at")
        .hasText("Feb 8, 2013", "follower followed at is visible");

      assert
        .dom(".activity-pub-actor-follow-btn")
        .exists("the ActivityPub actor follow btn is visible");
      await click(".activity-pub-actor-follow-btn");
      assert
        .dom(".modal.activity-pub-actor-follow-modal")
        .exists("shows the ActivityPub actor follow modal");
      assert.dom("#discourse-modal-title").hasText(
        i18n("discourse_activity_pub.actor_follow.title", {
          actor: "Cat 2",
        }),
        "ActivityPub actor follow modal has the right title"
      );

      assert
        .dom(".activity-pub-actor-unfollow-btn")
        .exists("the ActivityPub actor unfollow btn is visible");
      await click(".activity-pub-actor-unfollow-btn");
      assert
        .dom(".modal.activity-pub-actor-unfollow-modal")
        .exists("shows the ActivityPub actor unfollow modal");
      assert.dom("#discourse-modal-title").hasText(
        i18n("discourse_activity_pub.actor_unfollow.modal_title", {
          actor: "Cat 2",
        }),
        "ActivityPub actor unfollow modal has the right title"
      );
    });
  }
);
