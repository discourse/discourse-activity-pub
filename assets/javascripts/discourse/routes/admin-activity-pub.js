import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service(),

  afterModel(model, transition) {
    if (!this.site.activity_pub_enabled) {
      this.router.replaceWith("/404");
      return;
    }
    if (transition.targetName === "adminActivityPub.index") {
      this.router.transitionTo("adminActivityPubActor");
    }
  },
});
