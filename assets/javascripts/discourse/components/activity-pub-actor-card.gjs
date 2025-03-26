import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import ActivityPubActorModel from "./activity-pub-actor-model";
import ActivityPubFollowBtn from "./activity-pub-follow-btn";
import ActivityPubHandle from "./activity-pub-handle";

export default class ActivityPubActorCard extends Component {
  get followersPath() {
    return `/ap/local/actor/${this.args.actor.id}/followers`;
  }

  <template>
    <div class="activity-pub-actor-card">
      <div class="activity-pub-actor-card-top">
        <ActivityPubActorModel @actor={{@actor}} />
        <div class="follower-count activity-pub-actor-metadata">
          <a
            href={{this.followersPath}}
            class="activity-pub-actor-follower-count"
          >
            {{i18n
              "discourse_activity_pub.about.actor.follower_count"
              count=@actor.follower_count
            }}
          </a>
        </div>
      </div>
      <div class="activity-pub-actor-card-bottom">
        <ActivityPubHandle @actor={{@actor}} @hideLink={{true}} />
        <ActivityPubFollowBtn @actor={{@actor}} @type="follow" />
      </div>
    </div>
  </template>
}
