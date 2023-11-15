import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import ActivityPubWebfinger from "../../models/activity-pub-webfinger";
import ActivityPubActor from "../../models/activity-pub-actor";

export default class ActivityPubCreateFollow extends Component {
  @service site;

  @tracked verifying = false;
  @tracked error = null;
  @tracked followActor;

  get title() {
    return I18n.t("discourse_activity_pub.create_follow.title", {
      actor: this.args.model.name,
    });
  }

  get footerClass() {
    let result = "activity-pub-create-follow-find-footer";
    if (this.error) {
      result += " error";
    }
    return result;
  }

  get actorClass() {
    let result = "activity-pub-create-follow-actor-container";
    if (!this.followActor) {
      result += " no-actor";
    }
    return result;
  }

  get notFound() {
    return this.followActor === false;
  }

  @action
  onKeyup(e) {
    this.error = null;

    if (e.key === "Enter") {
      this.find();
    } else {
      this.followActor = null;
    }
  }

  @action
  async find() {
    const handle = this.handle;

    if (!handle) {
      return;
    }

    this.validating = true;
    const validated = await ActivityPubWebfinger.validateHandle(handle);
    this.validating = false;

    if (validated) {
      this.finding = true;
      const actorId = this.args.model.activity_pub_actor.id;
      this.followActor = await ActivityPubActor.findByHandle(actorId, handle);
      this.finding = false;
    } else {
      this.error = I18n.t("discourse_activity_pub.create_follow.find.invalid");
    }
  }
}
