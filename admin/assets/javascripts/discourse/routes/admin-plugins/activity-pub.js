import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsActivityPubRoute extends DiscourseRoute {
  @service router;

  afterModel(model, transition) {
    if (!this.site.activity_pub_enabled) {
      this.router.replaceWith("/404");
      return;
    }
    if (transition.targetName === "adminPlugins.activityPub.index") {
      this.router.transitionTo("adminPlugins.activityPub.actor");
    }
  }
}
