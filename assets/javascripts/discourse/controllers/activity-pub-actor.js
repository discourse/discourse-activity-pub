import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ActivityPubActor extends Controller {
  @service composer;
  @service site;
  @service currentUser;

  @action
  createTopic() {
    const props = {
      preferDraft: true,
    };
    if (this.category) {
      props.category = this.category;
    }
    if (this.tags) {
      props.tags = this.tags;
    }
    this.composer.openNewTopic(props);
  }
}
