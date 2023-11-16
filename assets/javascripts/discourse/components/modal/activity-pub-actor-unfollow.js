import Component from "@glimmer/component";
import { action } from "@ember/object";
import I18n from "I18n";

export default class ActivityPubActorUnfollow extends Component {
  get title() {
    return I18n.t("discourse_activity_pub.actor_unfollow.modal_title", {
      actor: this.args.model.actor.name,
    });
  }

  @action
  unfollow() {
    const model = this.args.model;
    model.unfollow(model.actor, model.followedActor);
    this.args.closeModal();
  }
}
