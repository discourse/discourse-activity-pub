import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { defaultHomepage } from "discourse/lib/utilities";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesActivityPubRoute extends RestrictedUserRoute {
  @service router;

  showFooter = true;

  afterModel() {
    if (!this.site.activity_pub_enabled) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }
    return ajax("/ap/auth.json")
      .then((result) => {
        this.authorizations = result.authorizations;
      })
      .catch(popupAjaxError);
  }

  setupController(controller) {
    controller.set("authorizations", this.authorizations);
    controller.showError();
  }
}
