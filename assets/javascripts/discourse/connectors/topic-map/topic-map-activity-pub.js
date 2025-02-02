import Component from "@glimmer/component";
import { activityPubTopicStatus } from "../../lib/activity-pub-utilities";

export default class TopicMapActivityPub extends Component {
  get topic() {
    return this.args.outletArgs.topic;
  }

  get showAcivityPubTopicMap() {
    return this.topic.activity_pub_enabled;
  }

  get topicStatus() {
    return activityPubTopicStatus(this.topic);
  }
}
