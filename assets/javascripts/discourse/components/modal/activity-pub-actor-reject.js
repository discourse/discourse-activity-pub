import Component from "@glimmer/component";
import { action } from "@ember/object";
import I18n from "I18n";

export default class ActivityPubActorReject extends Component {
  get title() {
    return I18n.t("discourse_activity_pub.actor_reject.modal_title", {
      actor: this.args.model.actor?.name,
    });
  }

  @action
  reject() {
    const model = this.args.model;
    model.reject(model.actor, model.followingActor);
    this.args.closeModal();
  }
}
