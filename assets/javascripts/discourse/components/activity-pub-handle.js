import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";
import copyText from "discourse/lib/copy-text";
import { tracked } from "@glimmer/tracking";

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
    const $copyRange = $('<p id="copy-range"></p>');
    $copyRange.html(this.handle);
    $(document.body).append($copyRange);
    if (copyText(this.handle, $copyRange[0])) {
      this.copied = true;
      discourseLater(() => {
        this.copied = false;
      }, 2000);
    }
    $copyRange.remove();
  }
}
