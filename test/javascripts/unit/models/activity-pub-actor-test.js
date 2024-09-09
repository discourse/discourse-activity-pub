import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { helperContext } from "discourse-common/lib/helpers";
import ActivityPubActor from "discourse/plugins/discourse-activity-pub/discourse/models/activity-pub-actor";

module("Unit | Model | activity-pub-actor", function (hooks) {
  setupTest(hooks);

  test("tagActors", function (assert) {
    assert.equal(ActivityPubActor.tagActors(), undefined, "empty by default");

    const fakeActors = {
      category: [],
      tag: [
        {
          id: 24,
          handle: "locale-intl-test@local.discourse.org",
          name: "Locale Intl",
          username: "locale-intl-test",
          model_id: 218,
          model_type: "tag",
          model_name: "locale-intl",
          can_admin: null,
          default_visibility: "public",
          publication_type: "first_post",
          post_object_type: "Note",
          enabled: true,
          ready: true,
        },
      ],
    };

    const { site } = helperContext();
    site.set("activity_pub_actors", fakeActors);

    assert.equal(
      ActivityPubActor.tagActors(),
      fakeActors.tag,
      "returns tag actors"
    );
  });
});
