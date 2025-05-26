import { or } from "truth-helpers";
import ActivityPubActorHandleLink from "./activity-pub-actor-handle-link";
import ActivityPubActorImage from "./activity-pub-actor-image";

const ActivityPubActor = <template>
  <div class="activity-pub-actor">
    {{#unless @hideImage}}
      <div class="activity-pub-actor-image">
        <ActivityPubActorImage @actor={{@actor}} @size="large" />
      </div>
    {{/unless}}
    <div class="activity-pub-actor-content">
      <div class="activity-pub-actor-name">
        {{or @actor.name @actor.username}}
      </div>
      <div class="activity-pub-actor-handle">
        <ActivityPubActorHandleLink @actor={{@actor}} />
      </div>
    </div>
  </div>
</template>;

export default ActivityPubActor;
