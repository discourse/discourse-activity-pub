import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

export default class ActivityPubAuthorize extends Component {
  @tracked domain = null;
  @tracked verifyingDomain = false;
  @tracked verifiedDomain = false;

  get containerClass() {
    return `control-group activity-pub-authorize activity-pub-authorize-${this.args.platform}`;
  }

  get title() {
    return I18n.t(
      `user.discourse_activity_pub.authorize.${this.args.platform}.title`
    );
  }

  get description() {
    return I18n.t(
      `user.discourse_activity_pub.authorize.${this.args.platform}.description`,
      {
        domain: window.location.hostname,
      }
    );
  }

  get placeholder() {
    return I18n.t(
      `user.discourse_activity_pub.authorize.${this.args.platform}.placeholder`
    );
  }

  get instructions() {
    return I18n.t(
      `user.discourse_activity_pub.authorize.${this.args.platform}.instructions`
    );
  }

  @action
  verifyDomain() {
    this.verifyingDomain = true;
    ajax("/ap/auth/verify.json", {
      data: {
        domain: this.domain,
        platform: this.args.platform,
      },
      type: "POST",
    })
      .then(() => {
        this.verifiedDomain = true;
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.verifyingDomain = false;
      });
  }

  @action
  clearDomain() {
    this.domain = null;
    this.verifiedDomain = false;
  }

  @action
  authorizeDomain() {
    window.open(getURL(`/ap/auth/authorize/${this.args.platform}`), "_self");
  }
}
