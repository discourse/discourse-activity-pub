import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import dIcon from "discourse/helpers/d-icon";
import {
  activityPubTopicStatus,
  activityPubTopicStatusText,
} from "../lib/activity-pub-utilities";
import ActivityPubTopicInfoModal from "./modal/activity-pub-topic-info";

export default class ActivityPubTopicStatus extends Component {
  @service modal;

  get topic() {
    return this.args.topic;
  }

  get statusText() {
    return activityPubTopicStatusText(this.topic);
  }

  get status() {
    return activityPubTopicStatus(this.topic);
  }

  get icon() {
    return this.status === "not_published"
      ? "discourse-activity-pub-slash"
      : "discourse-activity-pub";
  }

  get classes() {
    let placeClass = this.topic.activity_pub_local ? "local" : "remote";
    return `activity-pub-topic-status ${dasherize(this.status)} ${placeClass}`;
  }

  @action
  async showInfoModal() {
    const topic = this.topic;
    const firstPost = await topic.firstPost();
    this.modal.show(ActivityPubTopicInfoModal, { model: { topic, firstPost } });
  }

  <template>
    <div
      role="button"
      class={{this.classes}}
      title={{this.statusText}}
      {{on "click" this.showInfoModal}}
    >
      {{dIcon this.icon}}
      {{this.statusText}}
    </div>
  </template>
}
