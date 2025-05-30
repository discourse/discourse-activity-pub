import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import {
  removeSiteActor,
  updateSiteActor,
} from "../lib/activity-pub-utilities";
import ActivityPubActor from "./activity-pub-actor";
import ActivityPubActorModel from "./activity-pub-actor-model";

export default class ActivityPubActorAdminRow extends Component {
  @service dialog;
  @service router;
  @controller("adminPlugins.activityPub.actorShow") actorShowController;

  get actor() {
    return this.args.actor;
  }

  get status() {
    return this.actor.isDeleted
      ? "deleted"
      : this.actor.enabled
        ? "enabled"
        : "disabled";
  }

  get statusLabel() {
    return i18n(`admin.discourse_activity_pub.actor.${this.status}.label`);
  }

  get statusTitle() {
    return i18n(`admin.discourse_activity_pub.actor.${this.status}.title`);
  }

  @action
  editActor(actor) {
    this.router
      .transitionTo("adminPlugins.activityPub.actorShow", actor)
      .then(() => {
        this.actorShowController.set("showForm", true);
      });
  }

  @action
  restoreActor() {
    this.loading = true;
    this.actor.restore().then((result) => {
      if (result?.success) {
        this.actor.set("ap_type", result.actor_ap_type);
        updateSiteActor(this.actor);
      }
      this.loading = false;
    });
  }

  @action
  destroyActor() {
    this.dialog.deleteConfirm({
      title: i18n("admin.discourse_activity_pub.actor.destroy.confirm.title", {
        actor: this.actor.handle,
      }),
      message: i18n(
        "admin.discourse_activity_pub.actor.destroy.confirm.message",
        {
          actor: this.actor.handle,
          model: this.actor.model.name,
          model_type: this.actor.model_type,
        }
      ),
      confirmButtonLabel: "admin.discourse_activity_pub.actor.destroy.label",
      didConfirm: async () => {
        this.loading = true;
        this.actor.destroy().then((result) => {
          if (result?.success) {
            removeSiteActor(this.actor);
            this.args.removeActor(this.actor.id);
          }
          this.loading = false;
        });
      },
    });
  }

  <template>
    <div
      class="directory-table__row activity-pub-actor-table-row"
      data-actor-id={{this.actor.id}}
    >
      <div class="directory-table__cell activity-pub-actor-table-actor">
        <ActivityPubActor @actor={{this.actor}} />
      </div>
      <div class="directory-table__cell activity-pub-actor-table-model">
        <ActivityPubActorModel @actor={{this.actor}} />
      </div>
      <div class="directory-table__cell activity-pub-actor-table-status">
        <span title={{this.statusTitle}}>{{this.statusLabel}}</span>
      </div>
      <div class="directory-table__cell activity-pub-actor-table-actions">
        {{#if this.actor.isDeleted}}
          <DButton
            @action={{action "destroyActor"}}
            @label="admin.discourse_activity_pub.actor.destroy.label"
            @title="admin.discourse_activity_pub.actor.destroy.title"
            @icon="trash-can"
            class="activity-pub-destroy-actor-btn btn-danger"
            @disabled={{this.loading}}
          />
          <DButton
            @action={{action "restoreActor"}}
            @label="admin.discourse_activity_pub.actor.restore.label"
            @title="admin.discourse_activity_pub.actor.restore.title"
            @icon="arrow-rotate-left"
            class="activity-pub-restore-actor-btn btn-primary"
            @disabled={{this.loading}}
          />
        {{else}}
          <DButton
            @action={{action "editActor" this.actor}}
            @label="admin.discourse_activity_pub.actor.edit.label"
            @title="admin.discourse_activity_pub.actor.edit.title"
            @icon="pencil"
            class="activity-pub-edit-actor-btn"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
