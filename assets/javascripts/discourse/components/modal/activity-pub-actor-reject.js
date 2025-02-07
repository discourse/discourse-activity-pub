import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class ActivityPubActorReject extends Component {
  get title() {
    return i18n("discourse_activity_pub.actor_reject.modal_title", {
      actor: this.args.model.actor?.name,
    });
  }

  @action
  reject() {
    const model = this.args.model;
    model.reject(model.actor, model.follower);
    this.args.closeModal();
  }
}
