import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ActivityPubTopicInfo from "./activity-pub-topic-info";

export default class ActivityPubTopicAdmin extends Component {
  @service modal;

  get title() {
    return i18n("topic.discourse_activity_pub.admin.title", {
      topic_id: this.topic.id,
    });
  }

  get topic() {
    return this.args.model.topic;
  }

  get firstPost() {
    return this.args.model.firstPost;
  }

  @action
  showInfo() {
    this.modal.show(ActivityPubTopicInfo, {
      model: {
        firstPost: this.firstPost,
        topic: this.topic,
      },
    });
  }
}
