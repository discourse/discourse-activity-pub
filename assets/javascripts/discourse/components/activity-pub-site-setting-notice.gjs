import Component from "@glimmer/component";
import { dasherize } from "@ember/string";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class ActivityPubSiteSettingNotice extends Component {
  get containerClass() {
    return `activity-pub-site-setting ${dasherize(this.args.setting)}`;
  }

  get label() {
    return i18n(
      `admin.discourse_activity_pub.actor.site_setting.${this.args.setting}.label`
    );
  }

  get title() {
    return i18n(
      `admin.discourse_activity_pub.actor.site_setting.${this.args.setting}.title`
    );
  }

  get description() {
    return i18n(
      `admin.discourse_activity_pub.actor.site_setting.${this.args.setting}.description`,
      {
        model_type: this.args.modelType,
      }
    );
  }

  get url() {
    return getURL(
      `/admin/site_settings/category/all_results?filter=${this.args.setting}`
    );
  }

  <template>
    <div class={{this.containerClass}} title={{this.title}}>
      <div class="activity-pub-site-setting-label">
        <a href={{this.url}}>{{icon "gear"}}{{this.label}}</a>
      </div>
      <span>{{this.description}}</span>
    </div>
  </template>
}
