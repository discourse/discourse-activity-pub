import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import dIcon from "discourse/helpers/d-icon";
import {
  activityPubPostStatus,
  activityPubPostStatusText,
} from "../lib/activity-pub-utilities";
import ActivityPubPostModal from "./modal/activity-pub-post";

export default class ActivityPubPostStatus extends Component {
  @service modal;

  get post() {
    return this.args.post;
  }

  get statusText() {
    return activityPubPostStatusText(this.post, {
      postActor: this.post.topic.getActivityPubPostActor(this.post.id),
    });
  }

  get status() {
    return activityPubPostStatus(this.post);
  }

  get icon() {
    return this.status === "not_published"
      ? "discourse-activity-pub-slash"
      : "discourse-activity-pub";
  }

  get classes() {
    let placeClass = this.post.activity_pub_local ? "local" : "remote";
    return `activity-pub-post-status ${dasherize(this.status)} ${placeClass}`;
  }

  @action
  showInfoModal() {
    this.modal.show(ActivityPubPostModal, {
      model: {
        post: this.post,
      },
    });
  }

  <template>
    <div
      role="button"
      class={{this.classes}}
      title={{this.statusText}}
      {{on "click" this.showInfoModal}}
    >
      {{dIcon this.icon}}
    </div>
  </template>
}
