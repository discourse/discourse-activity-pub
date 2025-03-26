import { click, fillIn, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import { default as Mastodon } from "../fixtures/mastodon-fixtures";

const mastodonAboutPath = "api/v2/instance";

module(
  "Discourse Activity Pub | Component | activity-pub-follow-domain",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      Site.current().set("activity_pub_host", "forum.local");
      const category = Category.findById(2);
      category.set("activity_pub_actor", {
        handle: "announcements@forum.local",
      });
      this.model = category;
    });

    const template = hbs`<ActivityPubFollowDomain @actor={{this.model.activity_pub_actor}} />`;

    test("with a non domain input", async function (assert) {
      let domain = "notADomain";

      await render(template);
      await fillIn("#activity_pub_follow_domain_input", domain);
      await click("#activity_pub_follow_domain_button");

      assert.strictEqual(
        query(".activity-pub-follow-domain-footer.error").textContent.trim(),
        i18n("discourse_activity_pub.follow.domain.invalid"),
        "displays an invalid message"
      );
    });

    test("with a non activitypub domain", async function (assert) {
      let domain = "google.com";

      pretender.get(`https://${domain}/${mastodonAboutPath}`, () => {
        return response(404, "not found");
      });

      await render(template);
      await fillIn("#activity_pub_follow_domain_input", domain);
      await click("#activity_pub_follow_domain_button");

      assert.strictEqual(
        query(".activity-pub-follow-domain-footer.error")?.textContent.trim(),
        i18n("discourse_activity_pub.follow.domain.invalid"),
        "displays an invalid message"
      );
    });

    test("with an activitypub domain", async function (assert) {
      let domain = "mastodon.social";

      pretender.get(`https://${domain}/${mastodonAboutPath}`, () => {
        return response(Mastodon[`/${mastodonAboutPath}`]);
      });

      const openStub = sinon
        .stub(DiscourseURL, "redirectAbsolute")
        .returns(null);

      await render(template);
      await fillIn("#activity_pub_follow_domain_input", domain);
      await click("#activity_pub_follow_domain_button");

      const url = `https://${domain}/authorize_interaction?uri=${encodeURIComponent(
        "announcements@forum.local"
      )}`;
      assert.true(
        openStub.calledWith(url),
        "it loads the mastodon authorize interaction route in a new tab"
      );
    });
  }
);
