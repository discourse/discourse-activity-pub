import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class ActivityPubCategoryFollowers extends Controller {
  @tracked order = "";
  @tracked asc = null;

  queryParams = ["order", "asc"];

  @action
  loadMore() {
    this.model.loadMore();
  }
}
