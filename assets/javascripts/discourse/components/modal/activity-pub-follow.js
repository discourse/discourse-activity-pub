import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class ActivityPubFollow extends Component {
  get title() {
    return i18n("discourse_activity_pub.follow.title", {
      actor: this.args.model.actor.name,
    });
  }
}
