import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n from "I18n";

export default class ActivityPubAuthorization extends Component {
  @service dialog;

  @action
  remove() {
    const actorId = this.args.authorization.actor_id;
    this.dialog.yesNoConfirm({
      message: I18n.t(
        "user.discourse_activity_pub.authorization.confirm_remove",
        {
          actor_id: actorId,
        }
      ),
      didConfirm: () => {
        this.args.remove(actorId);
      },
    });
  }
}
