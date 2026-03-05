import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { trackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";
import ActivityPubActor, { newActor } from "../../../models/activity-pub-actor";

export default class AdminPluginsActivityPubActor extends Controller {
  @service router;

  @tracked order = "";
  @tracked asc = null;
  @tracked loadingMore = false;
  @tracked model_type = "category";
  @trackedArray actors;

  loadMoreUrl = "";
  total = "";

  queryParams = ["model_type", "order", "asc"];

  get hasActors() {
    return this.actors?.length > 0;
  }

  get title() {
    return i18n(`admin.discourse_activity_pub.actor.${this.model_type}.title`);
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
        this.actors.push(
          ...(response.actors || []).map((actor) => {
            return ActivityPubActor.create(actor);
          })
        );
        this.setProperties({
          loadMoreUrl: response.meta.load_more_url,
          total: response.meta.total,
          loadingMore: false,
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  addActor() {
    this.router
      .transitionTo("adminPlugins.activityPub.actorShow", newActor)
      .then(() => {
        this.actorShowController.set("showForm", false);
      });
  }

  @action
  removeActor(actorId) {
    this.actors = this.actors.filter((item) => item.id !== actorId);
  }
}
