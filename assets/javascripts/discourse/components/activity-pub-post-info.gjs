import Component from "@glimmer/component";
import dIcon from "discourse/helpers/d-icon";
import {
  activityPubPostStatus,
  activityPubPostStatusText,
} from "../lib/activity-pub-utilities";

export default class ActivityPubPostInfo extends Component {
  get post() {
    return this.args.post;
  }

  get status() {
    return activityPubPostStatus(this.post);
  }

  get statusText() {
    return activityPubPostStatusText(this.post, {
      infoStatus: true,
      postActor: this.post.topic.getActivityPubPostActor(this.post.id),
    });
  }

  get statusIcon() {
    if (this.status === "not_published") {
      return "far-circle-dot";
    } else {
      return this.post.activity_pub_local
        ? "circle-arrow-up"
        : "up-right-from-square";
    }
  }

  get linkPostStatus() {
    return !this.post.activity_pub_local && this.post.activity_pub_url;
  }

  get showDelivered() {
    return !!this.post.activity_pub_delivered_at;
  }

  get deliveredText() {
    return activityPubPostStatusText(this.post, {
      status: "delivered",
      infoStatus: true,
    });
  }

  <template>
    <div class="activity-pub-post-info">
      <span class="activity-pub-post-status">
        {{#if this.linkPostStatus}}
          <a
            href={{this.post.activity_pub_url}}
            target="_blank"
            rel="noopener noreferrer"
          >
            {{dIcon this.statusIcon}}{{this.statusText}}
          </a>
        {{else}}
          {{dIcon this.statusIcon}}{{this.statusText}}
        {{/if}}
      </span>
      {{#if this.showDelivered}}
        <span class="activity-pub-delivered">{{dIcon
            "envelope"
          }}{{this.deliveredText}}</span>
      {{/if}}
    </div>
  </template>
}
