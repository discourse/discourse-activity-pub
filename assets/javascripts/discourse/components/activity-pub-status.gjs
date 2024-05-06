import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { dasherize } from "@ember/string";
import icon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";
import ActivityPubActor from "../models/activity-pub-actor";

export default class ActivityPubStatus extends Component {
  @service siteSettings;
  @service site;
  @service messageBus;

  @tracked forComposer;
  @tracked ready;
  @tracked enabled;

  constructor() {
    super(...arguments);

    this.forComposer = this.args.modelType === "composer";

    const actor = this.findActor();
    if (actor) {
      this.ready = actor.ready;
      this.enabled = actor.enabled;
      this.messageBus.subscribe("/activity-pub", this.handleMessage);

      if (this.forComposer && !this.args.model.activity_pub_visibility) {
        this.args.model.activity_pub_visibility = actor.default_visibility;
      }
    }
  }

  findActor() {
    const category = this.forComposer
      ? this.args.model.category
      : this.args.model;
    const tags = this.forComposer ? this.args.model.tags : [this.args.model];

    let actor;

    if (category) {
      actor = ActivityPubActor.findByModel(category, "category");
    }
    if (!actor && tags) {
      tags.some((tag) => {
        if (tag) {
          actor = ActivityPubActor.findByModel(tag, "tag");
        }
        return !!actor;
      });
    }

    return actor;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  }

  @bind
  handleMessage(data) {
    const model = data.model;

    if (
      model &&
      model.type === this.args.modelType &&
      model.id === this.args.model.id
    ) {
      this.enabled = model.enabled;
      this.ready = model.ready;
    }
  }

  get active() {
    return this.site.activity_pub_enabled && this.enabled && this.ready;
  }

  get translatedTitle() {
    const args = {
      model_type: this.args.modelType,
    };
    if (this.active) {
      args.delay_minutes =
        this.siteSettings.activity_pub_delivery_delay_minutes;
    }
    return I18n.t(
      `discourse_activity_pub.status.title.${this.translatedTitleKey}`,
      args
    );
  }

  get translatedTitleKey() {
    if (!this.site.activity_pub_enabled) {
      return "plugin_disabled";
    }
    if (this.args.modelType === "category" && this.args.model.read_restricted) {
      return "category_read_restricted";
    }
    if (!this.enabled) {
      return "model_disabled";
    }
    if (!this.ready) {
      return "model_not_ready";
    }
    if (this.active) {
      if (!this.site.activity_pub_publishing_enabled) {
        return "publishing_disabled";
      }
      return "model_active.first_post";
    } else {
      return "model_not_active";
    }
  }

  get statusKey() {
    if (this.active) {
      return !this.site.activity_pub_publishing_enabled
        ? "publishing_disabled"
        : "active";
    } else {
      return "not_active";
    }
  }

  get classes() {
    let result = `activity-pub-status ${dasherize(this.statusKey)}`;
    if (this.args.onClick) {
      result += " clickable";
    }
    return result;
  }

  labelKey(type) {
    let attribute = "status";
    let key = this.statusKey;
    if (this.forComposer && this.site.activity_pub_publishing_enabled) {
      attribute = "visibility";
      key = this.args.model.activity_pub_visibility;
    }
    return `discourse_activity_pub.${attribute}.${type}.${key}`;
  }

  get translatedLabel() {
    return I18n.t(this.labelKey("label"));
  }

  <template>
    <div class={{this.classes}} title={{this.translatedTitle}} role="button">
      {{icon "discourse-activity-pub"}}
      <span class="label">{{this.translatedLabel}}</span>
    </div>
  </template>
}
