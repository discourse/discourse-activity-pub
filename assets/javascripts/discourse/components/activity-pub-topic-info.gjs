import Component from "@glimmer/component";
import dIcon from "discourse/helpers/d-icon";
import {
  activityPubTopicStatus,
  activityPubTopicStatusText,
} from "../lib/activity-pub-utilities";

export default class ActivityPubTopicInfo extends Component {
  get topic() {
    return this.args.topic;
  }

  get status() {
    return activityPubTopicStatus(this.topic);
  }

  get statusText() {
    return activityPubTopicStatusText(this.topic, {
      infoStatus: true,
    });
  }

  get statusIcon() {
    if (this.status === "not_published") {
      return "far-circle-dot";
    } else {
      return this.topic.activity_pub_local
        ? "circle-arrow-up"
        : "circle-arrow-down";
    }
  }

  <template>
    <div class="activity-pub-topic-info">
      <span class="activity-pub-topic-status">{{dIcon
          this.statusIcon
        }}{{this.statusText}}</span>
    </div>
  </template>
}
