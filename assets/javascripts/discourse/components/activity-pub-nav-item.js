import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";

export default class ActivityPubNavItem extends Component {
  @service router;
  @service messageBus;
  @service site;

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
    const category = this.args.category;
    this.visible =
      category?.activity_pub_ready &&
      (this.site.activity_pub_publishing_enabled || category.can_edit);
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
    const path = this.site.activity_pub_publishing_enabled
      ? "followers"
      : "follows";
    return getURL(`/ap/category/${this.args.category?.id}/${path}`);
  }

  get active() {
    return this.router.currentRouteName.includes("activityPub.category");
  }
}
