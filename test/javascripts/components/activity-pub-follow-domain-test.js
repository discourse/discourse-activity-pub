import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { default as Mastodon } from "../fixtures/mastodon-fixtures";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import sinon from "sinon";
import I18n from "I18n";

const mastodonAboutPath = "api/v2/instance";

module(
  "Discourse Activity Pub | Component | activity-pub-follow-domain",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      Site.current().set("activity_pub_host", "forum.local");
      const category = Category.findById(2);
      category.set("activity_pub_username", "announcements");
      this.model = category;
    });

    const template = hbs`<ActivityPubFollowDomain @model={{this.model}} />`;

    test("with a non domain input", async function (assert) {
      let domain = "notADomain";

      await render(template);
      await fillIn("#activity_pub_follow_domain_input", domain);
      await click("#activity_pub_follow_domain_button");

      assert.strictEqual(
        query(".activity-pub-follow-domain-footer.error").textContent.trim(),
        I18n.t("discourse_activity_pub.follow.domain.invalid"),
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
        query(".activity-pub-follow-domain-footer.error").textContent.trim(),
        I18n.t("discourse_activity_pub.follow.domain.invalid"),
        "displays an invalid message"
      );
    });

    test("with an activitypub domain", async function (assert) {
      let domain = "mastodon.social";

      pretender.get(`https://${domain}/${mastodonAboutPath}`, () => {
        return response(Mastodon[`/${mastodonAboutPath}`]);
      });

      const openStub = sinon.stub(window, "open").returns(null);

      await render(template);
      await fillIn("#activity_pub_follow_domain_input", domain);
      await click("#activity_pub_follow_domain_button");

      const url = `https://${domain}/authorize_interaction?uri=${encodeURIComponent(
        "announcements@forum.local"
      )}`;
      assert.strictEqual(
        openStub.calledWith(url, "_blank"),
        true,
        "it loads the mastodon authorize interaction route in a new tab"
      );
    });
  }
);
