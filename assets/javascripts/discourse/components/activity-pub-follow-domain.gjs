import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { extractDomainFromUrl, hostnameValid } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

// We're using a hardcoded url here as mastodon will only webfinger this as
// an ostatus template if the account is local, which is too limiting.
// See https://docs.joinmastodon.org/spec/webfinger
// See https://socialhub.activitypub.rocks/t/what-is-the-current-spec-for-remote-follow/2020
const mastodonFollowUrl = (domain, handle) => {
  return `https://${domain}/authorize_interaction?uri=${encodeURIComponent(
    handle
  )}`;
};

// See https://docs.joinmastodon.org/methods/instance/#v2
const mastodonAboutPath = "api/v2/instance";

export default class ActivityPubFollowDomain extends Component {
  @service site;

  @tracked verifying = false;
  @tracked error = null;

  get footerClass() {
    let result = "activity-pub-follow-domain-footer";
    if (this.error) {
      result += " error";
    }
    return result;
  }

  getFollowUrl(domain, handle) {
    return new Promise((resolve) => {
      if (!hostnameValid(domain)) {
        return resolve(null);
      }

      return ajax(`https://${domain}/${mastodonAboutPath}`, {
        type: "GET",
        ignoreUnsent: false,
      })
        .then((response) => {
          if (response?.domain && response.domain === domain) {
            return resolve(mastodonFollowUrl(domain, handle));
          } else {
            return resolve(null);
          }
        })
        .catch(() => resolve(null));
    });
  }

  @action
  onKeyup(e) {
    if (e.key === "Enter") {
      this.follow();
    }
  }

  @action
  async follow() {
    if (!this.domain) {
      return;
    }

    const handle = this.args.actor?.handle;
    if (!handle) {
      return;
    }

    this.error = null;
    this.verifying = true;

    const domain = extractDomainFromUrl(this.domain);
    const url = await this.getFollowUrl(domain, handle);

    this.verifying = false;

    if (url) {
      DiscourseURL.redirectAbsolute(url);
    } else {
      this.error = i18n("discourse_activity_pub.follow.domain.invalid");
    }
  }

  <template>
    <div class="activity-pub-follow-domain">
      <label>{{i18n "discourse_activity_pub.follow.domain.label"}}</label>
      <div class="activity-pub-follow-domain-controls inline-form">
        <Input
          {{on "keyup" this.onKeyup}}
          @value={{this.domain}}
          placeholder={{i18n
            "discourse_activity_pub.follow.domain.placeholder"
          }}
          id="activity_pub_follow_domain_input"
        />
        <DButton
          @icon="up-right-from-square"
          @action={{action "follow"}}
          @label="discourse_activity_pub.follow.domain.btn_label"
          @title="discourse_activity_pub.follow.domain.btn_title"
          @disabled={{this.verifying}}
          id="activity_pub_follow_domain_button"
        />
      </div>
      <div class={{this.footerClass}}>
        {{#if this.error}}
          {{this.error}}
        {{else if this.verifying}}
          {{i18n "discourse_activity_pub.follow.domain.verifying"}}
        {{else}}
          {{i18n "discourse_activity_pub.follow.domain.description"}}
        {{/if}}
      </div>
    </div>
  </template>
}
