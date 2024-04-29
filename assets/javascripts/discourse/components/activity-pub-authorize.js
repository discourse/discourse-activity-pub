import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

const supportedAuthTypes = ['discourse', 'mastodon'];

export default class ActivityPubAuthorize extends Component {
  @tracked authType = 'discourse';
  @tracked domain = null;
  @tracked verifyingDomain = false;
  @tracked verifiedDomain = false;

  get containerClass() {
    return `control-group activity-pub-authorize activity-pub-authorize-${this.authType}`;
  }

  get authTypes() {
    return supportedAuthTypes.map(authType => {
      return {
        id: authType,
        name: I18n.t(`user.discourse_activity_pub.authorize.${authType}.title`)
      };
    });
  }

  get title() {
    return I18n.t(
      `user.discourse_activity_pub.authorize.${this.authType}.title`
    );
  }

  get placeholder() {
    return I18n.t(
      `user.discourse_activity_pub.authorize.${this.authType}.placeholder`
    );
  }

  get mayContainUrl() {
    return this.domain && this.domain.length > 2 && this.domain.slice(1,-1).includes('.');
  }

  get verifyDisabled() {
    return this.verifyingDomain || !this.mayContainUrl;
  }

  @action
  verifyDomain() {
    this.verifyingDomain = true;
    ajax("/ap/auth/verify.json", {
      data: {
        domain: this.domain,
        auth_type: this.authType,
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
    window.open(getURL(`/ap/auth/authorize/${this.authType}`), "_self");
  }
}
