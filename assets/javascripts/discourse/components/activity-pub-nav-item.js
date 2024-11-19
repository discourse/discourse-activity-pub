import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";
import ActivityPubActor, {
  actorClientPath,
  actorModels,
} from "../models/activity-pub-actor";

export default class ActivityPubNavItem extends Component {
  @service router;
  @service messageBus;
  @service site;
  @service currentUser;

  @tracked visible = false;
  @tracked actor;
  @tracked model;

  @bind
  setup() {
    this.messageBus.subscribe("/activity-pub", this.handleActivityPubMessage);
    this.changeCategory();
    this.changeTag();
  }

  @bind
  teardown() {
    this.messageBus.unsubscribe("/activity-pub", this.handleActivityPubMessage);
  }

  @bind
  changeCategory() {
    if (this.args.category) {
      this.model = this.args.category;
      this.modelType = "category";
      this.modelName = this.model.name;
      this.changeModel();
    }
  }

  @bind
  changeTag() {
    if (this.args.tag) {
      this.model = this.args.tag;
      this.modelType = "tag";
      this.modelName = this.model.id;
      this.changeModel();
    }
  }

  changeModel() {
    const actor = ActivityPubActor.findByModel(this.model, this.modelType);
    if (actor && this.canAccess(actor)) {
      this.actor = actor;
      this.visible = true;
    } else {
      this.actor = null;
      this.visible = false;
    }
  }

  canAccess(actor) {
    return this.site.activity_pub_publishing_enabled || actor.can_admin;
  }

  @bind
  handleActivityPubMessage(data) {
    if (
      actorModels.includes(data.model.type) &&
      this.model &&
      data.model.id.toString() === this.model.id.toString()
    ) {
      this.visible = data.model.ready;
    }
  }

  get classes() {
    let result = "activity-pub-route-nav";
    if (this.visible) {
      result += " visible";
    }
    if (this.active) {
      result += " active";
    }
    return result;
  }

  get href() {
    if (!this.actor) {
      return;
    }
    const path = this.site.activity_pub_publishing_enabled
      ? "followers"
      : "follows";
    return getURL(`${actorClientPath}/${this.actor.id}/${path}`);
  }

  get title() {
    if (!this.model) {
      return "";
    }
    return I18n.t("discourse_activity_pub.discovery.description", {
      model_name: this.modelName,
    });
  }

  get active() {
    return this.router.currentRouteName.includes(`activityPub.actor`);
  }
}
