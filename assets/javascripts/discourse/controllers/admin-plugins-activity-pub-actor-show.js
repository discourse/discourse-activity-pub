import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { updateSiteActor, removeSiteActor } from "../lib/activity-pub-utilities";
import ActivityPubActor from "../models/activity-pub-actor";

export default class AdminPluginsActivityPubActorShow extends Controller {
  @service dialog;
  @service router;
  @service site;

  @tracked categoryId = null;
  @tracked tags = [];
  @tracked showForm = false;
  @tracked enabled = this.actor.enabled;
  @tracked loading = false;
  @tracked saveResponse = null;
  @tracked actor;

  modelTypes = [
    {
      id: "category",
      label: i18n("admin.discourse_activity_pub.actor.model_type.category"),
    },
    {
      id: "tag",
      label: i18n("admin.discourse_activity_pub.actor.model_type.tag"),
    },
  ];

  @equal("saveResponse", "success") saveSuccess;

  get canSave() {
    return this.showForm;
  }

  get canDelete() {
    return this.showForm && !this.actor.isNew;
  }

  get containerClass() {
    return `activity-pub-actor-${this.actor.isNew ? "add" : "edit"}`;
  }

  get titleLabel() {
    let key = this.actor.isNew ? `add.${this.actor.model_type}` : "edit";
    return i18n(`admin.discourse_activity_pub.actor.${key}.label`);
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
    this.loading = true;
    this.actor.save().then((result) => {
      if (result?.success) {
        updateSiteActor(result.actor);

        if (this.actor.isNew) {
          this.loading = false;
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
      this.loading = false;
    });
  }

  @action
  deleteActor() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.discourse_activity_pub.actor.delete.confirm", {
        actor: this.actor.handle,
      }),
      didConfirm: async () => {
        this.loading = true;
        this.actor.delete().then((result) => {
          if (result?.success) {
            this.loading = false;
            removeSiteActor(this.actor);
            return this.router.transitionTo(
              "adminPlugins.activityPub.actor"
            );
          } else {
            this.loading = false;
            this.deleteFailed = true;
            discourseLater(() => {
              this.deleteFailed = false;
            }, 3000);
          }
        });
      },
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

  @action
  changeTag(tags) {
    this.tags = tags;

    if (tags.length === 0) {
      this.showForm = false;
      return;
    }

    this.actor.model_type = "Tag";
    this.actor.model_name = tags[0];
    this.showForm = true;
  }
}
