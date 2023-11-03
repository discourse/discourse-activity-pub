import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import ActivityPubFollowModal from "../components/modal/activity-pub-follow";
import i18n from "discourse-common/helpers/i18n";
import DButton from "discourse/components/d-button";

export default class ActivityPubFollowBtn extends Component {
  @service modal;

  @action
  showModal() {
    this.modal.show(ActivityPubFollowModal, { model: this.args.category });
  }

  <template>
    <DButton
      @class="activity-pub-follow-btn"
      @action={{this.showModal}}
      @translatedLabel={{i18n "discourse_activity_pub.follow.label"}}
      @translatedTitle={{i18n
        "discourse_activity_pub.follow.title"
        name=@category.name
      }}
    />
  </template>
}
