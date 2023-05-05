import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";
import { tracked } from "@glimmer/tracking";
import { clipboardCopy } from "discourse/lib/utilities";

export default class ActivityPubHandle extends Component {
  @tracked copied = false;
  @service site;

  get handle() {
    if (!this.args.actor) {
      return undefined;
    } else {
      return `${this.args.actor.activity_pub_username}@${this.site.activity_pub_host}`;
    }
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
