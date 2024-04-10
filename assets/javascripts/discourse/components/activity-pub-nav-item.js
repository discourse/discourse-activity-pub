import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { actorClientPath, actorModels } from "../models/activity-pub-actor";

export default class ActivityPubNavItem extends Component {
  @service router;
  @service messageBus;
  @service site;
  @service currentUser;

  @tracked visible;
  @tracked actor;

  @bind
  subscribe() {
    this.messageBus.subscribe("/activity-pub", this.handleActivityPubMessage);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe("/activity-pub", this.handleActivityPubMessage);
  }

  @bind
  didChangeModel() {
    const actors = this.site.activity_pub_actors[this.args.modelType];
    if (!actors) {
      return;
    }

    const actor = actors.find((a) => a.model_id === this.args.model.id);
    if (actor && this.canAccess(actor)) {
      this.actor = actor;
      this.visible = true;
    }
  }

  canAccess(actor) {
    return this.site.activity_pub_publishing_enabled || actor.can_admin;
  }

  @bind
  handleActivityPubMessage(data) {
    if (
      actorModels.includes(data.model.type) &&
      this.args.model &&
      data.model.id.toString() === this.args.model.id.toString()
    ) {
      this.visible = data.model.ready;
    }
  }

  get classes() {
    let result = "activity-pub-route-nav";
    if (this.visible) {
      result += " visible";
    }
    if (this.active) {
      result += " active";
    }
    return result;
  }

  get href() {
    if (!this.actor) {
      return;
    }
    const path = this.site.activity_pub_publishing_enabled
      ? "followers"
      : "follows";
    return getURL(`${actorClientPath}/${this.actor.id}/${path}`);
  }

  get active() {
    return this.router.currentRouteName.includes(`activityPub.actor`);
  }
}
