import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n from "I18n";
import ActivityPubPostInfo from "./activity-pub-post-info";

export default class ActivityPubPostAdmin extends Component {
  @service modal;

  get title() {
    return I18n.t("post.discourse_activity_pub.admin.title", {
      post_number: this.post.post_number,
    });
  }

  get post() {
    return this.args.model.post;
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
