import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import ActivityPubNavItem from "../../components/activity-pub-nav-item";

@tagName("li")
@classNames("extra-nav-item-outlet", "activity-pub-navigation")
export default class ActivityPubNavigation extends Component {
  static shouldRender(attrs, context) {
    return context.site.activity_pub_enabled;
  }

  <template>
    <ActivityPubNavItem @category={{this.category}} @tag={{this.tag}} />
  </template>
}
