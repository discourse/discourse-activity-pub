import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import Category from "discourse/models/category";
import discourseLater from "discourse-common/lib/later";
import I18n from "I18n";
import ActivityPubActor from "../models/activity-pub-actor";

export default class AdminPluginsActivityPubActorShow extends Controller {
  @service dialog;
  @service router;
  @tracked categoryId = null;
  @tracked showForm = false;
  @tracked enabled = this.actor.enabled;
  @tracked saving = false;
  @tracked saveResponse = null;
  modelTypes = [
    {
      id: "category",
      label: I18n.t("admin.discourse_activity_pub.actor.model_type.category"),
    },
  ];

  @equal("saveResponse", "success") saveSuccess;

  get canSave() {
    return this.showForm;
  }

  get containerClass() {
    return `activity-pub-actor-${this.actor.isNew ? "add" : "edit"}`;
  }

  get titleLabel() {
    let key = this.actor.isNew ? "add" : "edit";
    return I18n.t(`admin.discourse_activity_pub.actor.${key}.label`);
  }

  get enabledLabel() {
    let key = this.enabled ? "enabled" : "disabled";
    return `admin.discourse_activity_pub.actor.${key}.label`;
  }

  @action
  goBack() {
    this.router.transitionTo("adminPlugins.activityPub.actor");
  }

  @action
  saveActor() {
    this.saving = true;
    this.actor.save().then((result) => {
      if (result?.success) {
        if (this.actor.isNew) {
          this.saving = false;
          return this.router.transitionTo(
            "adminPlugins.activityPub.actorShow",
            result.actor
          );
        }
        this.actor = ActivityPubActor.create(result.actor);
        this.saveResponse = "success";
      } else {
        this.saveResponse = "failed";
      }
      discourseLater(() => {
        this.saveResponse = null;
      }, 3000);
      this.saving = false;
    });
  }

  @action
  toggleEnabled() {
    if (this.enabled) {
      this.actor.disable().then((result) => {
        if (result?.success) {
          this.enabled = false;
        }
      });
    } else {
      this.actor.enable().then((result) => {
        if (result?.success) {
          this.enabled = true;
        }
      });
    }
  }

  @action
  changeCategoryId(categoryId) {
    if (categoryId) {
      this.categoryId = categoryId;
      this.actor.model = Category.findById(categoryId);
      this.actor.model_type = "Category";
      this.actor.model_id = categoryId;
      this.showForm = true;
    }
  }
}
