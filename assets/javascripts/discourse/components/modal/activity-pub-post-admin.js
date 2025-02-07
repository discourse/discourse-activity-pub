import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ActivityPubPostInfo from "./activity-pub-post-info";

export default class ActivityPubPostAdmin extends Component {
  @service modal;

  get title() {
    return i18n("post.discourse_activity_pub.admin.title", {
      post_number: this.post.post_number,
    });
  }

  get post() {
    return this.args.model.post;
  }

  get topic() {
    return this.post.topic;
  }

  @action
  showInfo() {
    this.modal.show(ActivityPubPostInfo, {
      model: {
        post: this.post,
      },
    });
  }
}
