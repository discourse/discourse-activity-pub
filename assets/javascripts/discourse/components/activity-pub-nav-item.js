import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";

export default class ActivityPubNavItem extends Component {
  @service router;

  get classes() {
    let result = "";
    if (this.active) {
      result += " active";
    }
    return result;
  }

  get href() {
    return getURL(`/ap/category/${this.args.category.id}/followers`);
  }

  get active() {
    return this.router.currentRouteName === "activityPub.category.followers";
  }
}
