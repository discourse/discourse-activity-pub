import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class PreferencesActivityPubController extends Controller {
  @tracked authorizations = null;
  @notEmpty("authorizations") hasAuthorizations;

  @action
  removeAuthorization(actorId) {
    ajax("/ap/auth/authorization.json", {
      data: { actor_id: actorId },
      type: "DELETE",
    })
      .then(() => {
        this.authorizations = this.authorizations.filter((a) => {
          return a.actor_id !== actorId;
        });
      })
      .catch(popupAjaxError);
  }
}
