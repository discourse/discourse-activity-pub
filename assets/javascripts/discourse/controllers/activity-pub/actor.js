import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ActivityPubActor extends Controller {
  @service composer;
  // eslint-disable-next-line discourse/no-unused-services
  @service site; // used in the template

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
