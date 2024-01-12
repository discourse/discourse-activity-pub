import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { dasherize } from "@ember/string";
import DButton from "discourse/components/d-button";
import I18n from "I18n";
import ActivityPubActorFollowModal from "../components/modal/activity-pub-actor-follow";
import ActivityPubActorUnfollowModal from "../components/modal/activity-pub-actor-unfollow";
import ActivityPubFollowModal from "../components/modal/activity-pub-follow";

const modalMap = {
  follow: ActivityPubFollowModal,
  actor_follow: ActivityPubActorFollowModal,
  actor_unfollow: ActivityPubActorUnfollowModal,
};

export default class ActivityPubFollowBtn extends Component {
  @service modal;

  @action
  showModal() {
    this.modal.show(modalMap[this.args.type], { model: this.args });
  }

  get class() {
    return `activity-pub-${dasherize(this.args.type)}-btn`;
  }

  get label() {
    return I18n.t(`discourse_activity_pub.${this.args.type}.label`);
  }

  get title() {
    return I18n.t(`discourse_activity_pub.${this.args.type}.title`, {
      actor: this.args.actor?.name,
    });
  }

  get icon() {
    switch (this.args.type) {
      case "follow":
        return "external-link-alt";
      case "actor_follow":
        return "plus";
      case "actor_unfollow":
        return "";
      default:
        return "";
    }
  }

  <template>
    <DButton
      @icon={{this.icon}}
      @action={{this.showModal}}
      @translatedLabel={{this.label}}
      @translatedTitle={{this.title}}
      class={{this.class}}
    />
  </template>
}
