import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n from "I18n";
import ActivityPubTopicAdmin from "./activity-pub-topic-admin";

export default class ActivityPubTopicInfoModal extends Component {
  @service modal;
  @service currentUser;

  get topic() {
    return this.args.model.topic;
  }

  get firstPost() {
    return this.args.model.firstPost;
  }

  get title() {
    return I18n.t("topic.discourse_activity_pub.info.title", {
      topic_id: this.topic.id,
    });
  }

  get canAdmin() {
    return this.currentUser?.staff;
  }

  @action
  showAdmin() {
    this.modal.show(ActivityPubTopicAdmin, {
      model: {
        firstPost: this.firstPost,
        topic: this.topic,
      },
    });
  }
}
