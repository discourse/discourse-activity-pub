import Controller, { inject as controller } from "@ember/controller";
import { readOnly } from "@ember/object/computed";
import { newActor } from "../../models/activity-pub-actor";

export default class AdminPluginsActivityPub extends Controller {
  @controller("admin-plugins.activity-pub.actor") adminPluginsActivityPubActor;

  @readOnly("adminPluginsActivityPubActor.model_type") modelType;

  get newActor() {
    return Object.assign({}, newActor, { model_type: this.modelType });
  }

  get addActorLabel() {
    return `admin.discourse_activity_pub.actor.add.${this.modelType}.label`;
  }

  get addActorClass() {
    return `activity-pub-add-actor ${this.modelType}`;
  }
}
