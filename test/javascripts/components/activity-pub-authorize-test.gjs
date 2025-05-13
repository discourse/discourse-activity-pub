import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ActivityPubAuthorize from "discourse/plugins/discourse-activity-pub/discourse/components/activity-pub-authorize";

module(
  "Discourse Activity Pub | Component | activity-pub-authorize",
  function (hooks) {
    setupRenderingTest(hooks);

    test("verifies a domain", async function (assert) {
      let domain = "test.com";
      let authType = "discourse";
      let requests = 0;

      pretender.post("/ap/auth/verify.json", (request) => {
        ++requests;
        assert.strictEqual(
          request.requestBody,
          `domain=${domain}&auth_type=${authType}`,
          "sets correct request parameters"
        );
        return response({ success: true });
      });

      await render(<template><ActivityPubAuthorize /></template>);

      const authTypes = selectKit("#user_activity_pub_authorize_auth_type");
      await authTypes.expand();
      await authTypes.selectRowByValue("discourse");

      await fillIn("#user_activity_pub_authorize_domain", domain);
      await click("#user_activity_pub_authorize_verify_domain");

      assert.strictEqual(requests, 1, "performs one request");
      assert
        .dom(".activity-pub-authorize-verified-domain span")
        .hasText(domain, "displays the verified domain");
      assert
        .dom("#user_activity_pub_authorize_clear_domain")
        .exists("displays the clear verified domain button");
      assert
        .dom("#user_activity_pub_authorize_authorize_domain")
        .exists("displays the authorize domain button");
    });

    test("pressing Enter in input triggers domain verification", async function (assert) {
      let domain = "test.com";
      let authType = "discourse";
      let requests = 0;

      pretender.post("/ap/auth/verify.json", (request) => {
        ++requests;
        assert.strictEqual(
          request.requestBody,
          `domain=${domain}&auth_type=${authType}`,
          "sets correct request parameters"
        );
        return response({ success: true });
      });

      await render(<template><ActivityPubAuthorize /></template>);

      const authTypes = selectKit("#user_activity_pub_authorize_auth_type");
      await authTypes.expand();
      await authTypes.selectRowByValue("discourse");

      await fillIn("#user_activity_pub_authorize_domain", domain);
      await triggerKeyEvent(
        "#user_activity_pub_authorize_domain",
        "keydown",
        "Enter"
      );

      assert.strictEqual(requests, 1, "performs one request");
    });

    test("clears a verified domain", async function (assert) {
      pretender.post("/ap/auth/verify.json", () => {
        return response({ success: true });
      });

      await render(<template><ActivityPubAuthorize /></template>);

      const authTypes = selectKit("#user_activity_pub_authorize_auth_type");
      await authTypes.expand();
      await authTypes.selectRowByValue("discourse");

      await fillIn("#user_activity_pub_authorize_domain", "test.com");
      await click("#user_activity_pub_authorize_verify_domain");
      await click("#user_activity_pub_authorize_clear_domain");

      assert
        .dom("#user_activity_pub_authorize_domain")
        .exists("displays the domain input");
      assert
        .dom("#user_activity_pub_authorize_domain")
        .hasNoText("the domain input is empty");
      assert
        .dom("#user_activity_pub_authorize_verify_domain")
        .exists("displays the verify domain button");
    });

    test("authorizes a verified domain", async function (assert) {
      let authType = "discourse";

      pretender.post("/ap/auth/verify.json", () => {
        return response({ success: true });
      });

      const openStub = sinon.stub(window, "open").returns(null);

      await render(<template><ActivityPubAuthorize /></template>);

      const authTypes = selectKit("#user_activity_pub_authorize_auth_type");
      await authTypes.expand();
      await authTypes.selectRowByValue("discourse");

      await fillIn("#user_activity_pub_authorize_domain", "test.com");
      await click("#user_activity_pub_authorize_verify_domain");
      await click("#user_activity_pub_authorize_authorize_domain");

      assert.true(
        openStub.calledWith(`/ap/auth/authorize/${authType}`, "_self"),
        "loads the authorize route in the current tab"
      );
    });
  }
);
