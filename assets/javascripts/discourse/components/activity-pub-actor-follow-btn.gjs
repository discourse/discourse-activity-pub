import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class ActivityPubActorFollowBtn extends Component {
  @tracked followed = !!this.args.followActor.followed_at;
  @tracked following = false;
  @tracked followRequested = false;

  @action
  follow() {
    if (this.followed || this.followRequested) {
      return;
    }

    this.following = true;

    this.args.follow(this.args.actor, this.args.followActor).then((result) => {
      this.followRequested = result;
      this.following = false;
    });
  }

  get icon() {
    if (this.followed) {
      return "user-check";
    } else if (this.followRequested) {
      return null;
    } else {
      return "user-plus";
    }
  }

  get i18nKey() {
    if (this.followed) {
      return "following";
    } else if (this.followRequested) {
      return "follow_requested";
    } else {
      return "follow";
    }
  }

  get title() {
    const opts = {
      actor: this.args.actor.username,
      follow_actor: this.args.followActor.username,
    };
    return i18n(
      `discourse_activity_pub.actor_follow.${this.i18nKey}.title`,
      opts
    );
  }

  get label() {
    return i18n(`discourse_activity_pub.actor_follow.${this.i18nKey}.label`);
  }

  <template>
    <DButton
      @action={{this.follow}}
      @icon={{this.icon}}
      @translatedLabel={{this.label}}
      @translatedTitle={{this.title}}
      @disabled={{this.following}}
      class="activity-pub-follow-actor-btn"
    />
  </template>
}
