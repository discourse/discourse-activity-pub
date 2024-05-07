import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { cloneJSON } from "discourse-common/lib/object";
import { default as SiteActors } from "../fixtures/site-actors-fixtures";

module("Integration | Component | activity-pub-tag-chooser", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());

    this.site.setProperties({
      top_tags: ["tag_1", "tag_2"],
      activity_pub_actors: cloneJSON(SiteActors),
    });

    pretender.get("/tags/filter/search", (params) => {
      if (params.queryParams.q === "tag") {
        return response({
          results: [
            { id: "tag_1", name: "Tag 1", count: 2, pm_only: false },
            { id: "tag_2", name: "Tag 2", count: 3, pm_only: false },
          ],
        });
      } else {
        return response({
          results: [],
        });
      }
    });
  });

  test("when search has no results", async function (assert) {
    await render(hbs`
      <ActivityPubTagChooser @tagId={{this.tag}} />
    `);

    await this.subject.expand();

    let content = this.subject.displayedContent();
    assert.strictEqual(
      content.length,
      2,
      "it shows the correct number of tags"
    );

    await this.subject.fillInFilter("not-tag");

    content = this.subject.displayedContent();
    assert.strictEqual(
      content.length,
      0,
      "it shows the correct number of tags"
    );
  });

  test("when hasActor is true only tags with actors are returned", async function (assert) {
    await render(hbs`
      <ActivityPubTagChooser @tagId={{this.tag}} @options={{hash hasActor=true}} />
    `);

    await this.subject.expand();
    await this.subject.fillInFilter("tag");

    const content = this.subject.displayedContent();
    assert.strictEqual(
      content.length,
      1,
      "it shows the correct number of tags"
    );
    assert.strictEqual(content[0].id, "tag_1", "it shows the correct tag");
  });

  test("when hasActor is false only tags without actors are returned", async function (assert) {
    await render(hbs`
      <ActivityPubTagChooser @tagId={{this.tag}} @options={{hash hasActor=false}} />
    `);

    await this.subject.expand();
    await this.subject.fillInFilter("tag");

    const content = this.subject.displayedContent();
    assert.strictEqual(
      content.length,
      1,
      "it shows the correct number of tags"
    );
    assert.strictEqual(content[0].id, "tag_2", "it shows the correct tag");
  });
});
