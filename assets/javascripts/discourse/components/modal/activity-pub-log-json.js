import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";
import discourseLater from "discourse-common/lib/later";

export default class ActivityPubLogJson extends Component {
  @tracked copied = false;

  get jsonDisplay() {
    return JSON.stringify(this.args.model.log.json, null, 4);
  }

  @action
  copyToClipboard() {
    clipboardCopy(this.args.model.log.json);
    this.copied = true;
    discourseLater(() => {
      this.copied = false;
    }, 3000);
  }
}
