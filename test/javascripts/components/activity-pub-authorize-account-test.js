import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { click, render } from "@ember/test-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { module, test } from "qunit";
import sinon from "sinon";

module(
  "Discourse Activity Pub | Component | activity-pub-authorize-account",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<ActivityPubAuthorizeAccount />`;

    test("verifies a domain", async function (assert) {
      let domain = "test.com";
      let requests = 0;

      pretender.post("/ap/auth/oauth/verify.json", (request) => {
        ++requests;
        assert.strictEqual(
          request.requestBody,
          `domain=${domain}`,
          "it sets correct request parameters"
        );
        return response({ success: true });
      });

      await render(template);
      await fillIn("#user_activity_pub_authorize_account_domain", domain);
      await click("#user_activity_pub_authorize_account_verify_domain");

      assert.strictEqual(requests, 1, "performs one request");
      assert.strictEqual(
        query(".activity-pub-authorize-account-verified-domain label")
          .textContent,
        domain,
        "displays the verified domain"
      );
      assert.ok(
        exists("#user_activity_pub_authorize_account_clear_domain"),
        "displays the clear verified domain button"
      );
      assert.ok(
        exists("#user_activity_pub_authorize_account_authorize_domain"),
        "displays the authorize domain button"
      );
    });

    test("clears a verified domain", async function (assert) {
      pretender.post("/ap/auth/oauth/verify.json", () => {
        return response({ success: true });
      });

      await render(template);
      await fillIn("#user_activity_pub_authorize_account_domain", "test.com");
      await click("#user_activity_pub_authorize_account_verify_domain");
      await click("#user_activity_pub_authorize_account_clear_domain");

      assert.ok(
        exists("#user_activity_pub_authorize_account_domain"),
        "displays the domain input"
      );
      assert.strictEqual(
        query("#user_activity_pub_authorize_account_domain").textContent,
        "",
        "the domain input is empty"
      );
      assert.ok(
        exists("#user_activity_pub_authorize_account_verify_domain"),
        "displays the verify domain button"
      );
    });

    test("authorizes a verified domain", async function (assert) {
      pretender.post("/ap/auth/oauth/verify.json", () => {
        return response({ success: true });
      });

      const openStub = sinon.stub(window, "open").returns(null);

      await render(template);
      await fillIn("#user_activity_pub_authorize_account_domain", "test.com");
      await click("#user_activity_pub_authorize_account_verify_domain");
      await click("#user_activity_pub_authorize_account_authorize_domain");

      assert.strictEqual(
        openStub.calledWith("/ap/auth/oauth/authorize", "_self"),
        true,
        "it loads the authorize route in the current tab"
      );
    });
  }
);
