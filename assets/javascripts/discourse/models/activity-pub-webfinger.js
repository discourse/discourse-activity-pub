import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const ActivityPubWebfinger = EmberObject.extend({});

ActivityPubWebfinger.reopenClass({
  validateHandle(handle) {
    return ajax({
      url: "/webfinger/handle/validate",
      type: "POST",
      data: {
        handle,
      },
    })
      .then((response) => response?.valid)
      .catch(popupAjaxError);
  },
});

export default ActivityPubWebfinger;
