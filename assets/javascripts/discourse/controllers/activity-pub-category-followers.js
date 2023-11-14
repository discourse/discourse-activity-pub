import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class ActivityPubCategoryFollowers extends Controller {
  @service composer;
  @service siteSettings;

  @tracked order = "";
  @tracked asc = null;

  queryParams = ["order", "asc"];

  @action
  loadMore() {
    this.model.loadMore();
  }
}
