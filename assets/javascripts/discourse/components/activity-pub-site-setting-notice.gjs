import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { dasherize } from "@ember/string";
import icon from "discourse-common/helpers/d-icon";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

export default class ActivityPubSiteSettingNotice extends Component {
  @service siteSettings;

  get containerClass() {
    return `activity-pub-site-setting ${dasherize(this.args.setting)}`;
  }

  get label() {
    return I18n.t(
      `admin.discourse_activity_pub.actor.site_setting.${this.args.setting}.label`
    );
  }

  get title() {
    return I18n.t(
      `admin.discourse_activity_pub.actor.site_setting.${this.args.setting}.title`
    );
  }

  get description() {
    return I18n.t(
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
        <a href={{this.url}}>{{icon "cog"}}{{this.label}}</a>
      </div>
      <span>{{this.description}}</span>
    </div>
  </template>
}
