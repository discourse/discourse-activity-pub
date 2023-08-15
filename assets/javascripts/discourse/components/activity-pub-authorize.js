import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";
import getURL from "discourse-common/lib/get-url";

export default class ActivityPubAuthorize extends Component {
  @tracked domain = null;
  @tracked verifyingDomain = false;
  @tracked verifiedDomain = false;

  @action
  verifyDomain() {
    this.verifyingDomain = true;
    ajax("/ap/auth/oauth/verify.json", {
      data: { domain: this.domain },
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
    window.open(getURL("/ap/auth/oauth/authorize"), "_self");
  }
}
