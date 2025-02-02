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
import ActivityPubPostInfoModal from "./modal/activity-pub-post-info";

export default class ActivityPubPostStatus extends Component {
  @service modal;

  get statusText() {
    return activityPubPostStatusText(this.args.post);
  }

  get status() {
    return activityPubPostStatus(this.args.post);
  }

  get icon() {
    return this.status === "not_published"
      ? "discourse-activity-pub-slash"
      : "discourse-activity-pub";
  }

  get classes() {
    let placeClass = this.args.post.activity_pub_local ? "local" : "remote";
    return `activity-pub-post-status ${dasherize(this.status)} ${placeClass}`;
  }

  @action
  showInfoModal() {
    this.modal.show(ActivityPubPostInfoModal, {
      model: {
        post: this.args.post,
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
