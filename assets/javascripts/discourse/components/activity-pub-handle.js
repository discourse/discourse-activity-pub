import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";
import { tracked } from "@glimmer/tracking";
import { clipboardCopy } from "discourse/lib/utilities";
import { buildHandle } from "../lib/activity-pub-utilities";

export default class ActivityPubHandle extends Component {
  @tracked copied = false;
  @service site;
  @service siteSettings;

  get handle() {
    const model = this.args.model;
    const actor = this.args.actor;
    const site = this.site;
    return buildHandle({ actor, model, site });
  }

  @action
  copy() {
    clipboardCopy(this.handle);
    this.copied = true;
    discourseLater(() => {
      this.copied = false;
    }, 2000);
  }
}
