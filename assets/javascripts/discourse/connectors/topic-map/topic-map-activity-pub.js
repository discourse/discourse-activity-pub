import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  activityPubTopicStatus,
  showStatusToUser,
} from "../../lib/activity-pub-utilities";

export default class TopicMapActivityPub extends Component {
  @service currentUser;
  @service siteSettings;
  @service site;

  get topic() {
    return this.args.outletArgs.topic;
  }

  get showAcivityPubTopicMap() {
    return (
      this.site.activity_pub_enabled &&
      this.topic.activity_pub_enabled &&
      showStatusToUser(this.currentUser, this.siteSettings)
    );
  }

  get topicStatus() {
    return activityPubTopicStatus(this.topic);
  }
}
