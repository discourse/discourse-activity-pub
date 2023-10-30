import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class ActivityPubFollowersBtn extends Component {
  @service router;

  get label() {
    return I18n.t('discourse_activity_pub.followers.label', {
      count: this.args.category.activity_pub_follower_count
    })
  }

  get title() {
    return I18n.t('discourse_activity_pub.followers.title', {
      count: this.args.category.activity_pub_follower_count
    })
  }

  get classes() {
    let result = "activity-pub-followers-btn";
    if (this.router.currentRouteName === 'activityPub.category.followers') {
      result += " active";
    }
    return result;
  }

  @action
  goToFollowers() {
    this.router.transitionTo(`/ap/category/${this.args.category.id}/followers`);
  }
};
