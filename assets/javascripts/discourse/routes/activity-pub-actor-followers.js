import { A } from "@ember/array";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor from "../models/activity-pub-actor";

export default DiscourseRoute.extend({
  site: service(),

  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  afterModel(_, transition) {
    const actor = this.modelFor("activityPub.actor");

    if (!actor.can_admin && !this.site.activity_pub_publishing_enabled) {
      this.router.replaceWith("/404");
      return;
    }

    return ActivityPubActor.list(
      actor.id,
      transition.to.queryParams,
      "followers"
    ).then((response) => this.setProperties(response));
  },

  setupController(controller) {
    controller.setProperties({
      actor: this.modelFor("activityPub.actor"),
      actors: A(this.actors || []),
      loadMoreUrl: this.meta?.load_more_url,
      total: this.meta?.total,
    });
  },
});
