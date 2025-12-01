import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { trackedArray } from "discourse/lib/tracked-tools";

export default class ActivityPubActorFollowers extends Controller {
  @tracked order = "";
  @tracked asc = null;
  @tracked loadingMore = false;
  @trackedArray actors;

  queryParams = ["order", "asc"];

  get hasActors() {
    return this.actors?.length > 0;
  }

  get tableClass() {
    let result = "activity-pub-follow-table followers";
    if (this.currentUser?.admin) {
      result += " show-controls";
    }
    return result;
  }

  @action
  async loadMore() {
    if (!this.loadMoreUrl || this.total <= this.actors.length) {
      return;
    }

    this.loadingMore = true;

    try {
      const response = await ajax(this.loadMoreUrl);
      if (response) {
        this.actors.push(...response.actors);
        this.setProperties({
          loadMoreUrl: response.meta.load_more_url,
          loadingMore: false,
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
