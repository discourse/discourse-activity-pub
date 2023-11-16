import Component from "@glimmer/component";
import I18n from "I18n";

export default class ActivityPubFollow extends Component {
  get title() {
    return I18n.t("discourse_activity_pub.follow.title", {
      actor: this.args.model.actor.name,
    });
  }
}
