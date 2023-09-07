import Controller from "@ember/controller";
import { notEmpty } from "@ember/object/computed";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";

export default class PreferencesActivityPubController extends Controller {
  @notEmpty("authorizations") hasAuthorizations;
  @tracked authorizations = null;

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
