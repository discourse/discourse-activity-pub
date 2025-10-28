import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ActivityPubActorFollows extends Controller {
  @tracked order = "";
  @tracked asc = null;
  @tracked loadingMore = false;

  queryParams = ["order", "asc"];

  @notEmpty("actors") hasActors;

  get tableClass() {
    let result = "activity-pub-follow-table follows";
    if (this.actor?.can_admin) {
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
