import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ActivityPubActorFollowers extends Controller {
  @tracked order = "";
  @tracked asc = null;

  queryParams = ["order", "asc"];

  @notEmpty("actors") hasActors;

  get tableClass() {
    let result = "activity-pub-follow-table followers";
    if (this.currentUser?.admin) {
      result += " show-controls";
    }
    return result;
  }

  @action
  loadMore() {
    if (!this.loadMoreUrl || this.total <= this.actors.length) {
      return;
    }

    this.set("loadingMore", true);

    return ajax(this.loadMoreUrl)
      .then((response) => {
        if (response) {
          this.follows.pushObjects(response.actors);
          this.setProperties({
            loadMoreUrl: response.meta.load_more_url,
            loadingMore: false,
          });
        }
      })
      .catch(popupAjaxError);
  }
}
