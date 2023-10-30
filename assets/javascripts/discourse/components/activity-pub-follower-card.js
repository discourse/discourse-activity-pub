import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class ActivityPubFollowerCard extends Component {
  @service siteSettings;
  @service site;

  get imageSize() {
    return this.site.mobileView ? 'small' : 'huge';
  }

  get classes() {
    let result = 'activity-pub-follower-card';
    if (this.site.mobileView) {
      result += ' mobile';
    } else {
      result += ' desktop';
    }
    return result;
  }
}
