import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminActivityPubRoute extends DiscourseRoute {
  @service router;

  afterModel(model, transition) {
    if (!this.site.activity_pub_enabled) {
      this.router.replaceWith("/404");
      return;
    }
    if (transition.targetName === "adminActivityPub.index") {
      this.router.transitionTo("adminActivityPubActor");
    }
  }
}
