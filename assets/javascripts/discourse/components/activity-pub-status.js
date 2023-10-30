import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";

export default class ActivityPubStatus extends Component {
  @service siteSettings;
  @service site;
  @service messageBus;

  @tracked forComposer;
  @tracked category;
  @tracked ready;
  @tracked enabled;

  constructor() {
    super(...arguments);

    this.forComposer = this.args.modelType === "composer";
    this.category = this.forComposer
      ? this.args.model.category
      : this.args.model;

    if (this.category) {
      this.ready = this.category.activity_pub_ready;
      this.enabled = this.category.activity_pub_enabled;
      this.messageBus.subscribe("/activity-pub", this.handleMessage);

      if (this.forComposer && !this.args.model.activity_pub_visibility) {
        this.args.model.activity_pub_visibility = this.category.activity_pub_default_visibility;
      }
    }
  }

  willDestroy() {
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
    if (this.args.translatedTitle) {
      return this.args.translatedTitle;
    }

    const args = {
      model_type: this.args.modelType,
    };
    if (this.active) {
      args.category_name = this.category.name;
      args.delay_minutes = this.siteSettings.activity_pub_delivery_delay_minutes;
    }
    return I18n.t(
      `discourse_activity_pub.status.title.${this.translatedTitleKey}`,
      args
    );
  }

  get translatedTitleKey() {
    if (this.siteSettings.login_required) {
      return "login_required_enabled";
    }
    if (!this.siteSettings.activity_pub_enabled) {
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
      return "model_active.first_post";
    } else {
      return "model_not_active";
    }
  }

  get statusKey() {
    return this.active ? "active" : "not_active";
  }

  get classes() {
    let result = `activity-pub-status ${this.statusClass}`;
    if (this.args.onClick) {
      result += " clickable";
    }
    return result;
  }

  get statusClass() {
    return this.active ? "active" : "not-active";
  }

  labelKey(type) {
    let attribute = this.forComposer ? "visibility" : "status";
    let key = this.forComposer
      ? this.args.model.activity_pub_visibility
      : this.statusKey;
    return `discourse_activity_pub.${attribute}.${type}.${key}`;
  }

  get translatedLabel() {
    if (this.args.translatedLabel) {
      return this.args.translatedLabel;
    } else {
      return I18n.t(this.labelKey("label"));
    }
  }

  @action
  click(event) {
    if (this.args.onClick) {
      this.args.onClick(event);
    }
  }
}
