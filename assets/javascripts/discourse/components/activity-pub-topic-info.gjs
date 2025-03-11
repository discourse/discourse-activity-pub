import Component from "@glimmer/component";
import { service } from "@ember/service";
import dIcon from "discourse/helpers/d-icon";
import { activityPubTopicStatusText } from "../lib/activity-pub-utilities";

export default class ActivityPubTopicInfo extends Component {
  @service("activity-pub-topic-tracking-state") apTopicTrackingState;

  get topic() {
    return this.args.topic;
  }

  get attributes() {
    return this.apTopicTrackingState.getAttributes(this.topic.id);
  }

  get status() {
    return this.apTopicTrackingState.getStatus(this.topic.id);
  }

  get statusText() {
    return activityPubTopicStatusText({
      actor: this.topic.activity_pub_actor.handle,
      attributes: this.attributes,
      status: this.status,
      info: true,
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
