import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import ActivityPubFollowModal from "../components/modal/activity-pub-follow";

export default class ActivityPubFollowBtn extends Component {
  @service modal;

  @action
  showModal() {
    this.modal.show(ActivityPubFollowModal, { model: this.args.category });
  }
}
