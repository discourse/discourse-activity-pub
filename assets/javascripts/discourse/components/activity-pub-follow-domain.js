import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { extractDomainFromUrl, hostnameValid } from "discourse/lib/utilities";
import I18n from "I18n";

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
      window.open(url, "_blank")?.focus();
    } else {
      this.error = I18n.t("discourse_activity_pub.follow.domain.invalid");
    }
  }
}
