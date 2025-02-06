import Component from "@glimmer/component";
import { activityPubTopicActors } from "../lib/activity-pub-utilities";
import ActivityPubHandle from "./activity-pub-handle";

export default class ActivityPubPublicationInfo extends Component {
  get actors() {
    return activityPubTopicActors(this.args.topic);
  }

  <template>
    <div class="activity-pub-admin-info">
      <div class="activity-pub-admin-info-actors">
        {{#each this.actors as |actor|}}
          <ActivityPubHandle @actor={{actor}} @hideCopy={{true}} />
        {{/each}}
      </div>
    </div>
  </template>
}
