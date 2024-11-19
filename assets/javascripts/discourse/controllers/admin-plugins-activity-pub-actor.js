import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import ActivityPubActor, { newActor } from "../models/activity-pub-actor";

export default class AdminPluginsActivityPubActor extends Controller {
  @service router;
  @controller("adminPlugins.activityPub.actorShow") actorShowController;
  @tracked order = "";
  @tracked asc = null;
  @tracked model_type = "category";
  loadMoreUrl = "";
  total = "";

  @notEmpty("actors") hasActors;

  queryParams = ["model_type", "order", "asc"];

  get title() {
    return I18n.t(
      `admin.discourse_activity_pub.actor.${this.model_type}.title`
    );
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
          this.actors.pushObjects(
            (response.actors || []).map((actor) => {
              return ActivityPubActor.create(actor);
            })
          );
          this.setProperties({
            loadMoreUrl: response.meta.load_more_url,
            total: response.meta.total,
            loadingMore: false,
          });
        }
      })
      .catch(popupAjaxError);
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
  editActor(actor) {
    this.router
      .transitionTo("adminPlugins.activityPub.actorShow", actor)
      .then(() => {
        this.actorShowController.set("showForm", true);
      });
  }
}
