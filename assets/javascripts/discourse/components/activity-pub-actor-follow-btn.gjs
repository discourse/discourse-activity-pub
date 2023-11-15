import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import I18n from "discourse-i18n";
import DButton from "discourse/components/d-button";
import ActivityPubActor from "../models/activity-pub-actor";

export default class ActivityPubActorFollowBtn extends Component {
  @tracked followed = false;
  @tracked following = false;

  constructor() {
    super(...arguments);

    this.followed = !!this.args.followActor.followed_at;
  }

  @action
  follow() {
    if (this.followed) {
      return;
    }

    this.following = true;

    ActivityPubActor
      .follow(this.args.actor.id, this.args.followActor.id)
      .then(result => {
        this.followed = result;
      })
      .finally(() => {
        this.following = false;
      })
  }

  get icon() {
    return this.followed ? "user-check" : "user-plus" ;
  }

  get title() {
    const opts = {
      actor: this.args.actor.username,
      follow_actor: this.args.followActor.username
    }
    const key = this.followed ? 'following' : 'follow';
    return I18n.t(`discourse_activity_pub.create_follow.${key}.title`, opts);
  }

  get label() {
    const key = this.followed ? 'following' : 'follow';
    return I18n.t(`discourse_activity_pub.create_follow.${key}.label`);
  }

  <template>
    <DButton
      @class="activity-pub-follow-actor-btn"
      @action={{this.follow}}
      @icon={{this.icon}}
      @translatedLabel={{this.label}}
      @translatedTitle={{this.title}}
      @disabled={{this.following}}
    />
  </template>
}
