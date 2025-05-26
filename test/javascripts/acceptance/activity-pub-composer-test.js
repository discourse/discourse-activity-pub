import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import SiteActors from "../fixtures/site-actors-fixtures";

acceptance("Discourse Activity Pub | composer", function (needs) {
  needs.user();

  test("without a category", async function (assert) {
    Site.current().setProperties({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: cloneJSON(SiteActors),
    });

    await visit("/");
    await click("#create-topic");

    assert
      .dom("#reply-control .activity-pub-actor-status")
      .doesNotExist("the status label is not visible");
  });

  test("with a category with activity pub ready", async function (assert) {
    Site.current().setProperties({
      activity_pub_enabled: true,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: cloneJSON(SiteActors),
    });

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit("#reply-control .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom("#reply-control .activity-pub-actor-status")
      .exists("the status label is visible");
    assert
      .dom("#reply-control .activity-pub-actor-status .label")
      .hasText(
        i18n("discourse_activity_pub.visibility.label.public"),
        "the status label has the right text"
      );
  });

  test("when the plugin is disabled", async function (assert) {
    Site.current().setProperties({
      activity_pub_enabled: false,
      activity_pub_publishing_enabled: true,
      activity_pub_actors: cloneJSON(SiteActors),
    });

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit("#reply-control .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom("#reply-control .activity-pub-actor-status")
      .doesNotExist("the status label is not visible");
  });
});
