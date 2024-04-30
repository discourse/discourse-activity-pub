import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const ActivityPubAuthorization = EmberObject.extend();

ActivityPubAuthorization.reopenClass({
  remove(authId) {
    return ajax(`/ap/auth/destroy/${authId}.json`, {
      type: "DELETE",
    }).catch(popupAjaxError);
  },
});

export default ActivityPubAuthorization;
