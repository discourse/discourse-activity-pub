import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const supportedAuthTypes = ["discourse", "mastodon"];

export default class ActivityPubAuthorize extends Component {
  @tracked authType = null;
  @tracked domain = null;
  @tracked verifyingDomain = false;
  @tracked verifiedDomain = false;

  get containerClass() {
    let result = "activity-pub-authorize";
    if (this.authType) {
      result += ` ${this.authType}`;
    }
    return result;
  }

  get authTypes() {
    return supportedAuthTypes.map((authType) => {
      return {
        id: authType,
        name: i18n(
          `user.discourse_activity_pub.authorize.auth_type.${authType}.title`
        ),
      };
    });
  }

  get title() {
    return i18n(
      `user.discourse_activity_pub.authorize.auth_type.${
        this.authType || "none"
      }.title`
    );
  }

  get placeholder() {
    return i18n(
      `user.discourse_activity_pub.authorize.auth_type.${
        this.authType || "none"
      }.placeholder`
    );
  }

  get mayContainDomain() {
    return (
      this.domain &&
      this.domain.length > 2 &&
      this.domain.slice(1, -1).includes(".")
    );
  }

  get verifyDisabled() {
    return (
      !this.authType ||
      this.verifiedDomain ||
      this.verifyingDomain ||
      !this.mayContainDomain
    );
  }

  get verifyBtnClass() {
    return `activity-pub-authorize-verify-domain ${
      this.verifyDisabled ? "" : " btn-primary"
    }`;
  }

  get authorizeDisabled() {
    return !this.verifiedDomain;
  }

  get authorizeBtnClass() {
    return `activity-pub-authorize-domain ${
      this.authorizeDisabled ? "" : " btn-primary"
    }`;
  }

  @action
  verifyDomain() {
    this.verifyingDomain = true;
    ajax("/ap/auth/verify.json", {
      data: {
        domain: this.domain,
        auth_type: this.authType,
      },
      type: "post",
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
  onDomainKeyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();

      this.verifyDomain();
    }
  }

  @action
  authorizeDomain() {
    window.open(getURL(`/ap/auth/authorize/${this.authType}`), "_self");
  }
}
