import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import ActivityPubCreateFollowModal from "../components/modal/activity-pub-create-follow";
import i18n from "discourse-common/helpers/i18n";
import DButton from "discourse/components/d-button";

export default class ActivityPubCreateFollowBtn extends Component {
  @service modal;

  @action
  showModal() {
    this.modal.show(ActivityPubCreateFollowModal, { model: this.args.category });
  }

  <template>
    <DButton
      @class="activity-pub-follow-btn"
      @action={{this.showModal}}
      @icon="plus"
      @translatedLabel={{i18n "discourse_activity_pub.create_follow.label"}}
      @translatedTitle={{i18n
        "discourse_activity_pub.create_follow.title"
        name=@category.name
      }}
    />
  </template>
}
