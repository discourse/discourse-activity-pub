import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class ActivityPubNavItem extends Component {
  @service router;
  @service messageBus;

  @tracked visible;

  @bind
  subscribe() {
    this.messageBus.subscribe("/activity-pub", this.handleActivityPubMessage);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe("/activity-pub", this.handleActivityPubMessage);
  }

  @bind
  didChangeCategory() {
    this.visible = this.args.category?.activity_pub_ready;
  }

  @bind
  handleActivityPubMessage(data) {
    if (
      data.model.type === "category" &&
      this.args.category &&
      data.model.id.toString() === this.args.category.id.toString()
    ) {
      this.visible = data.model.ready;
    }
  }

  get classes() {
    let result = "activity-pub-category-route-nav";
    if (this.visible) {
      result += " visible";
    }
    if (this.active) {
      result += " active";
    }
    return result;
  }

  get href() {
    return getURL(`/ap/category/${this.args.category?.id}/followers`);
  }

  get active() {
    return this.router.currentRouteName.includes("activityPub.category");
  }
}
