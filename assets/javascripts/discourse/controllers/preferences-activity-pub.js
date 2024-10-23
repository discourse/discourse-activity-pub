import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import ActivityPubAuthorization from "../models/activity-pub-authorization";

export default class PreferencesActivityPubController extends Controller {
  @service dialog;
  @tracked authorizations = null;
  @tracked error;
  @notEmpty("authorizations") hasAuthorizations;

  queryParams = ["error"];

  clearError() {
    this.error = null;
  }

  showError() {
    if (this.error) {
      this.dialog.alert();
      this.dialog.alert({
        title: I18n.t("user.discourse_activity_pub.authorize_error.title"),
        message: this.error,
        didConfirm: () => this.clearError(),
        didCancel: () => this.clearError(),
      });
    }
  }

  @action
  remove(authorization) {
    this.dialog.yesNoConfirm({
      message: I18n.t(
        "user.discourse_activity_pub.authorization.confirm_remove",
        {
          handle: authorization.actor?.handle,
        }
      ),
      didConfirm: () => {
        ActivityPubAuthorization.remove(authorization.id).then((result) => {
          if (result.success) {
            this.authorizations = this.authorizations.filter((a) => {
              return a.id !== authorization.id;
            });
          }
        });
      },
    });
  }
}
