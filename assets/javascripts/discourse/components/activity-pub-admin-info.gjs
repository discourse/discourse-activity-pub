import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import { activityPubTopicActors } from "../lib/activity-pub-utilities";
import ActivityPubHandle from "./activity-pub-handle";

export default class ActivityPubPublicationInfo extends Component {
  get description() {
    let opts = {};
    if (this.args.context === "post") {
      opts.post_number = this.args.post.post_number;
    } else if (this.args.context === "topic") {
      opts.topic_id = this.args.topic.id;
    }
    return i18n(
      `${this.args.context}.discourse_activity_pub.info.actors`,
      opts
    );
  }

  get actors() {
    return activityPubTopicActors(this.args.topic);
  }

  <template>
    <div class="activity-pub-admin-info">
      <div class="activity-pub-admin-info-actors">
        <div class="label">{{this.description}}</div>
        <div class="content">
          {{#each this.actors as |actor|}}
            <ActivityPubHandle @actor={{actor}} @hideCopy={{true}} />
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
