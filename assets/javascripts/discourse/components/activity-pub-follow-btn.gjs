import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ActivityPubActorFollowModal from "../components/modal/activity-pub-actor-follow";
import ActivityPubActorRejectModal from "../components/modal/activity-pub-actor-reject";
import ActivityPubActorUnfollowModal from "../components/modal/activity-pub-actor-unfollow";
import ActivityPubFollowModal from "../components/modal/activity-pub-follow";

const modalMap = {
  follow: ActivityPubFollowModal,
  actor_follow: ActivityPubActorFollowModal,
  actor_unfollow: ActivityPubActorUnfollowModal,
  actor_reject: ActivityPubActorRejectModal,
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
    return i18n(`discourse_activity_pub.${this.args.type}.label`);
  }

  get title() {
    return i18n(`discourse_activity_pub.${this.args.type}.title`, {
      actor: this.args.actor?.name,
    });
  }

  get icon() {
    switch (this.args.type) {
      case "follow":
        return "";
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
