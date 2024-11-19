import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesActivityPubRoute extends RestrictedUserRoute {
  @service router;

  showFooter = true;

  setupController(controller, user) {
    if (!this.site.activity_pub_enabled) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }
    controller.set("authorizations", user.activity_pub_authorizations);
  }
}
