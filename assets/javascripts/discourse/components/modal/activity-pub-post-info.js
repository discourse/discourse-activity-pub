import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ActivityPubPostAdmin from "./activity-pub-post-admin";

export default class ActivityPubPostInfoModal extends Component {
  @service modal;
  @service currentUser;

  get post() {
    return this.args.model.post;
  }

  get title() {
    return i18n("post.discourse_activity_pub.info.title", {
      post_number: this.post.post_number,
    });
  }

  get canAdmin() {
    return this.currentUser?.staff;
  }

  @action
  showAdmin() {
    this.modal.show(ActivityPubPostAdmin, {
      model: {
        post: this.post,
      },
    });
  }
}
