import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { bind } from "discourse/lib/decorators";
import DiscourseRoute from "discourse/routes/discourse";
import ActivityPubActor from "../../../models/activity-pub-actor";

export default class ActivityPubActorFollows extends DiscourseRoute {
  queryParams = {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  };

  afterModel(_, transition) {
    const actor = this.modelFor("activityPub.actor");
    return ActivityPubActor.list(
      actor.id,
      transition.to.queryParams,
      "follows"
    ).then((response) => this.setProperties(response));
  }

  setupController(controller) {
    controller.setProperties({
      actor: this.modelFor("activityPub.actor"),
      actors: new TrackedArray(this.actors || []),
      loadMoreUrl: this.meta?.load_more_url,
      total: this.meta?.total,
    });
  }

  activate() {
    this.messageBus.subscribe("/activity-pub", this.handleMessage);
  }

  deactivate() {
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  }

  @bind
  handleMessage(data) {
    const model = data.model;
    const actor = this.modelFor("activityPub.actor");
    if (model && model.type === "category" && model.id === actor.id) {
      this.refresh();
    }
  }
}
