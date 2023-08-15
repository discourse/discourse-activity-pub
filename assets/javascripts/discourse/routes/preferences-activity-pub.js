import RestrictedUserRoute from "discourse/routes/restricted-user";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default class PreferencesActivityPubRoute extends RestrictedUserRoute {
  @service router;

  showFooter = true;

  setupController(controller, user) {
    if (!this.site.activity_pub_enabled) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }
    controller.set("model", user);
  }
}
