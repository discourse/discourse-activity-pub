import { A } from "@ember/array";
import DiscourseRoute from "discourse/routes/discourse";
import { bind } from "discourse-common/utils/decorators";
import ActivityPubActor from "../models/activity-pub-actor";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  afterModel(_, transition) {
    const actor = this.modelFor("activityPub.actor");

    if (!actor.can_admin) {
      this.router.replaceWith("/404");
      return;
    }

    return ActivityPubActor.list(
      actor.id,
      transition.to.queryParams,
      "follows"
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

  activate() {
    this.messageBus.subscribe("/activity-pub", this.handleMessage);
  },

  deactivate() {
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  },

  @bind
  handleMessage(data) {
    const model = data.model;
    const actor = this.modelFor("activityPub.actor");
    if (model && model.type === "category" && model.id === actor.id) {
      this.refresh();
    }
  },
});
