import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class ActivityPubStatus extends Component {
  @service siteSettings;
  @service messageBus;

  @tracked ready;
  @tracked enabled;

  constructor() {
    super(...arguments);

    this.ready = this.args.model.activity_pub_ready;
    this.enabled = this.args.model.activity_pub_enabled;
    this.messageBus.subscribe("/activity-pub", this.handleMessage);
  }

  willDestroy() {
    this.messageBus.unsubscribe("/activity-pub", this.handleMessage);
  }

  @bind
  handleMessage(data) {
    const model = data.model;

    if (model && (model.type === this.args.modelType && model.id === this.args.model.id)) {
      this.enabled = model.enabled;
      this.ready = model.ready;
    }
  }

  get active() {
    return !this.siteSettings.login_required &&
      this.siteSettings.activity_pub_enabled &&
      this.enabled &&
      this.ready;
  }

  get translatedTitle() {
    return I18n.t(`discourse_activity_pub.status.title.${this.translatedTitleKey}`, {
      model_type: this.args.modelType
    })
  }

  get translatedTitleKey() {
    if (this.siteSettings.login_required) {
      return "login_required_enabled";
    }
    if (!this.siteSettings.activity_pub_enabled) {
      return "plugin_disabled";
    }
    if (!this.enabled) {
      return "model_disabled";
    }
    if (!this.ready) {
      return "model_not_ready";
    }
    return this.active ? "model_active" : "model_not_active";
  }

  get labelKey() {
    return this.active ? "active" : "not_active";
  }

  get statusClass() {
    return this.active ? "active" : "not-active";
  }
}