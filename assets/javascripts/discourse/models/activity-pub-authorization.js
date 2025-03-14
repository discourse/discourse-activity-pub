import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ActivityPubAuthorization {
  static remove(authId) {
    return ajax(`/ap/auth/destroy/${authId}.json`, {
      type: "DELETE",
    }).catch(popupAjaxError);
  }
}
