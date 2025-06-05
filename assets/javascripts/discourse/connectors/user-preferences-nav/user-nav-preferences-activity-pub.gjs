import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNames("user-preferences-nav-outlet", "user-nav-preferences-activity-pub")
export default class UserNavPreferencesActivityPub extends Component {
  <template>
    {{#if this.site.activity_pub_enabled}}
      <LinkTo @route="preferences.activity-pub">
        {{icon "discourse-activity-pub"}}
        <span>{{i18n "user.discourse_activity_pub.title"}}</span>
      </LinkTo>
    {{/if}}
  </template>
}
