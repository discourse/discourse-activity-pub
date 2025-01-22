import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export const logAdminPath = "/admin/plugins/ap/log";

class ActivityPubLog extends EmberObject {}

ActivityPubLog.reopenClass({
  list(params) {
    const queryParams = new URLSearchParams();

    if (params.order) {
      queryParams.set("order", params.order);
    }

    if (params.asc) {
      queryParams.set("asc", params.asc);
    }

    const path = logAdminPath;

    let url = `${path}.json`;
    if (queryParams.size) {
      url += `?${queryParams.toString()}`;
    }

    return ajax(url).catch(popupAjaxError);
  },
});

export default ActivityPubLog;
