import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import ActivityPubActor from "../../models/activity-pub-actor";
import ActivityPubWebfinger from "../../models/activity-pub-webfinger";

export default class ActivityPubFollowRemote extends Component {
  @service site;

  @tracked verifying = false;
  @tracked error = null;
  @tracked followActor;

  get title() {
    return I18n.t("discourse_activity_pub.actor_follow.title", {
      actor: this.args.model.actor.name,
    });
  }

  get footerClass() {
    let result = "activity-pub-actor-follow-find-footer";
    if (this.error) {
      result += " error";
    }
    return result;
  }

  get actorClass() {
    let result = "activity-pub-actor-follow-actor-container";
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
  follow(actor, followActor) {
    return this.args.model.follow(actor, followActor).then(() => {
      this.args.closeModal();
    });
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
      this.followActor = await ActivityPubActor.findByHandle(
        this.args.model.actor.id,
        handle
      );
      this.finding = false;
    } else {
      this.error = I18n.t("discourse_activity_pub.actor_follow.find.invalid");
    }
  }
}
