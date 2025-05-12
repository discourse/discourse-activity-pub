import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <div class={{this.containerClass}}>
      <div class="controls">
        <ComboBox
          @id="user_activity_pub_authorize_auth_type"
          class="activity-pub-authorize-auth-type"
          @content={{this.authTypes}}
          @value={{this.authType}}
          @onChange={{fn (mut this.authType)}}
          @disabled={{this.verifiedDomain}}
          @options={{hash
            none="user.discourse_activity_pub.authorize.auth_type.none.label"
          }}
        />
        {{#if this.verifiedDomain}}
          <span class="activity-pub-authorize-verified-domain">
            <span>{{this.domain}}</span>
            <DButton
              @icon="xmark"
              @action={{action "clearDomain"}}
              @title="user.discourse_activity_pub.clear_domain_button.title"
              id="user_activity_pub_authorize_clear_domain"
              class="activity-pub-authorize-clear-domain"
            />
          </span>
        {{else}}
          <Input
            @value={{this.domain}}
            disabled={{this.verifyingDomain}}
            placeholder={{this.placeholder}}
            id="user_activity_pub_authorize_domain"
            {{on "keydown" this.onDomainKeyDown}}
          />
        {{/if}}
        <DButton
          @icon="check"
          @action={{action "verifyDomain"}}
          @label="user.discourse_activity_pub.verify_domain_button.label"
          @title="user.discourse_activity_pub.verify_domain_button.title"
          @disabled={{this.verifyDisabled}}
          id="user_activity_pub_authorize_verify_domain"
          class={{this.verifyBtnClass}}
        />
        <DButton
          @icon="fingerprint"
          @action={{action "authorizeDomain"}}
          @label="user.discourse_activity_pub.authorize_button.label"
          @title="user.discourse_activity_pub.authorize_button.title"
          @disabled={{this.authorizeDisabled}}
          id="user_activity_pub_authorize_authorize_domain"
          class={{this.authorizeBtnClass}}
        />
      </div>
    </div>
  </template>
}
