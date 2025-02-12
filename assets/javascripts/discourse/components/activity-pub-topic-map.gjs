import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  activityPubTopicStatus,
  showStatusToUser,
} from "../lib/activity-pub-utilities";
import ActivityPubTopicStatus from "./activity-pub-topic-status";

export default class ActivityPubTopicMap extends Component {
  @service currentUser;
  @service siteSettings;
  @service site;

  get topic() {
    return this.args.outletArgs.topic;
  }

  get showActivityPubTopicMap() {
    return (
      this.site.activity_pub_enabled &&
      this.topic.activity_pub_enabled &&
      showStatusToUser(this.currentUser, this.siteSettings)
    );
  }

  get topicStatus() {
    return activityPubTopicStatus(this.topic);
  }

  <template>
    {{yield}}
    {{#if this.showActivityPubTopicMap}}
      <section class="topic-map__activity-pub">
        <ActivityPubTopicStatus @topic={{this.topic}} />
      </section>
    {{/if}}
  </template>
}
