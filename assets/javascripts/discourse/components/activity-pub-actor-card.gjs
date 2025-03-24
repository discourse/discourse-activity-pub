import { i18n } from "discourse-i18n";
import ActivityPubActorModel from "./activity-pub-actor-model";
import ActivityPubFollowBtn from "./activity-pub-follow-btn";
import ActivityPubHandle from "./activity-pub-handle";

const ActivityPubActorCard = <template>
  <div class="activity-pub-actor-card">
    <div class="activity-pub-actor-card-top">
      <ActivityPubHandle @actor={{@actor}} @hideLink={{true}} />
      <ActivityPubFollowBtn @actor={{@actor}} @type="follow" />
    </div>
    <div class="activity-pub-actor-card-bottom">
      <ActivityPubActorModel @actor={{@actor}} />
      <div class="follower-count activity-pub-actor-metadata">
        {{i18n
          "discourse_activity_pub.about.actor.follower_count"
          count=@actor.follower_count
        }}
      </div>
    </div>
  </div>
</template>;

export default ActivityPubActorCard;
